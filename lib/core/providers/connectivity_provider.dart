import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/services/offline_action_service.dart';

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier(ref);
});

class ConnectivityState {
  final bool isOnline;
  final bool wasOffline;

  const ConnectivityState({this.isOnline = true, this.wasOffline = false});

  ConnectivityState copyWith({bool? isOnline, bool? wasOffline}) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      wasOffline: wasOffline ?? this.wasOffline,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Ref _ref;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityNotifier(this._ref) : super(const ConnectivityState()) {
    _init();
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    final online = _isOnline(result);
    state = ConnectivityState(isOnline: online);
    _sub = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final online = _isOnline(results);
    final wasOffline = !state.isOnline && online;
    state = state.copyWith(isOnline: online, wasOffline: wasOffline);

    if (wasOffline) {
      _replayPendingActions();
    }
  }

  Future<void> _replayPendingActions() async {
    try {
      final service = _ref.read(offlineActionServiceProvider);
      await service.replayAll();
    } catch (_) {}
  }

  void dismissReconnected() {
    state = state.copyWith(wasOffline: false);
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
