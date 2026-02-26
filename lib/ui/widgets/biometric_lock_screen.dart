import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/services/biometric_service.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricLockScreen({super.key, required this.child});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled = ref.read(biometricEnabledProvider);
    if (!enabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;

    final service = ref.read(biometricServiceProvider);
    final success = await service.authenticate();

    if (mounted) {
      setState(() {
        _locked = !success;
        _authenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricEnabledProvider);

    if (!enabled || !_locked) return widget.child;

    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 64,
                color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Lunaris is locked', style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _authenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
