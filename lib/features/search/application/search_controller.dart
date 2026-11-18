import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../data/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(supabaseProvider)),
);

final searchResultsProvider = FutureProvider.family<List<SearchHit>, String>((
  ref,
  query,
) {
  if (query.trim().length < 2) return Future.value(const []);
  return ref.watch(searchRepositoryProvider).search(query);
});
