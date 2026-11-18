import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/garden_repository.dart';
import '../domain/garden.dart';

final gardenRepositoryProvider = Provider<GardenRepository>(
  (ref) => GardenRepository(ref.watch(supabaseProvider)),
);

final gardenEventsProvider = FutureProvider.family<List<GardenEvent>, String?>((
  ref,
  projectId,
) {
  return ref.watch(gardenRepositoryProvider).listEvents(projectId: projectId);
});
