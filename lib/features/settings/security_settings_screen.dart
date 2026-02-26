import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunaris/core/services/biometric_service.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final service = ref.read(biometricServiceProvider);
    final available = await service.isAvailable();
    if (mounted) setState(() => _available = available);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(biometricEnabledProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        children: [
          if (!BiometricService.isSupported)
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Biometrics not supported'),
              subtitle: Text('This platform does not support biometrics'),
            )
          else if (!_available)
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('Biometrics not available'),
              subtitle: Text(
                'No biometric hardware or enrollment found',
              ),
            )
          else ...[
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric Lock'),
              subtitle: const Text(
                'Require authentication when returning to the app',
              ),
              value: enabled,
              onChanged: (v) async {
                if (v) {
                  final service = ref.read(biometricServiceProvider);
                  final authenticated = await service.authenticate(
                    reason: 'Verify your identity to enable biometric lock',
                  );
                  if (!authenticated) return;
                }
                ref.read(biometricEnabledProvider.notifier).toggle(v);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'When enabled, you\'ll need to authenticate using your device\'s biometrics or PIN whenever you return to Lunaris.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
