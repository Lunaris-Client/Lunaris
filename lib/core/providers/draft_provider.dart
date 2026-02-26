import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/api/discourse_api_client.dart';
import 'package:lunaris/core/auth/auth_service.dart';
import 'package:lunaris/core/providers/providers.dart';

class DraftParams {
  final String serverUrl;
  final String draftKey;

  const DraftParams({required this.serverUrl, required this.draftKey});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftParams &&
          serverUrl == other.serverUrl &&
          draftKey == other.draftKey;

  @override
  int get hashCode => Object.hash(serverUrl, draftKey);
}

class DraftState {
  final String raw;
  final String? title;
  final int? categoryId;
  final List<String> tags;
  final int? replyToPostNumber;
  final bool isSaving;

  const DraftState({
    this.raw = '',
    this.title,
    this.categoryId,
    this.tags = const [],
    this.replyToPostNumber,
    this.isSaving = false,
  });

  DraftState copyWith({
    String? raw,
    String? title,
    int? categoryId,
    List<String>? tags,
    int? replyToPostNumber,
    bool? isSaving,
  }) {
    return DraftState(
      raw: raw ?? this.raw,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      replyToPostNumber: replyToPostNumber ?? this.replyToPostNumber,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  String toJson() {
    return jsonEncode({
      'raw': raw,
      if (title != null) 'title': title,
      if (categoryId != null) 'categoryId': categoryId,
      if (tags.isNotEmpty) 'tags': tags,
      if (replyToPostNumber != null) 'replyToPostNumber': replyToPostNumber,
    });
  }
}

class DraftNotifier extends StateNotifier<DraftState> {
  final DiscourseApiClient _apiClient;
  final AuthService _authService;
  final DraftParams _params;
  Timer? _saveTimer;

  DraftNotifier(this._apiClient, this._authService, this._params)
    : super(const DraftState());

  void update({
    String? raw,
    String? title,
    int? categoryId,
    List<String>? tags,
    int? replyToPostNumber,
  }) {
    state = state.copyWith(
      raw: raw,
      title: title,
      categoryId: categoryId,
      tags: tags,
      replyToPostNumber: replyToPostNumber,
    );
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 5), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (state.raw.trim().isEmpty && (state.title ?? '').trim().isEmpty) return;

    state = state.copyWith(isSaving: true);
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;

      await _apiClient.saveDraft(
        _params.serverUrl,
        apiKey,
        draftKey: _params.draftKey,
        data: state.toJson(),
      );
    } catch (_) {
    } finally {
      if (mounted) state = state.copyWith(isSaving: false);
    }
  }

  Future<void> discard() async {
    _saveTimer?.cancel();
    try {
      final apiKey = await _authService.loadApiKey(_params.serverUrl);
      if (apiKey == null) return;
      await _apiClient.deleteDraft(
        _params.serverUrl,
        apiKey,
        draftKey: _params.draftKey,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

final draftProvider =
    StateNotifierProvider.family<DraftNotifier, DraftState, DraftParams>((
      ref,
      params,
    ) {
      return DraftNotifier(
        ref.watch(discourseApiClientProvider),
        ref.watch(authServiceProvider),
        params,
      );
    });
