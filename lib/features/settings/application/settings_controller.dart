import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseProvider)),
);

final profileProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).getProfile();
});

final settingsActionsProvider = NotifierProvider<SettingsActions, bool>(
  SettingsActions.new,
);

class SettingsActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> setTheme(ThemeMode mode) async {
    await ref.read(themeModeProvider.notifier).setMode(mode);
    await ref
        .read(profileRepositoryProvider)
        .getProfile(); // mantiene la sesión viva
  }

  Future<void> updateDisplayName(String name) async {
    await ref.read(profileRepositoryProvider).updateDisplayName(name);
    ref.invalidate(profileProvider);
  }

  Future<void> completeOnboarding() async {
    await ref.read(profileRepositoryProvider).completeOnboarding();
    ref.invalidate(profileProvider);
  }
}
