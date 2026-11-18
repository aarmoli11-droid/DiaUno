import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/async_view.dart';
import '../application/search_controller.dart';
import '../data/search_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider(_term));
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              TextField(
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Proyectos, tareas, eventos, suscripciones…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _query.clear();
                            setState(() => _term = '');
                          },
                        ),
                ),
                onChanged: (value) => setState(() => _term = value.trim()),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_term.length < 2)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'Escribe al menos 2 caracteres',
                    message:
                        'La búsqueda respeta los permisos de proyecto de tu cuenta.',
                  ),
                )
              else
                Expanded(
                  child: AsyncView(
                    value: results,
                    empty: (list) => list.isEmpty,
                    builder: (context, hits) => ListView.separated(
                      itemCount: hits.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final hit = hits[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(_iconFor(hit.kind)),
                          title: Text(
                            hit.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(hit.subtitle),
                          onTap: () {
                            final route = hit.targetRoute;
                            if (route == null) return;
                            if (hit.kind == SearchKind.project ||
                                hit.kind == SearchKind.event) {
                              context.push(route);
                            } else {
                              context.push(route);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(SearchKind kind) => switch (kind) {
  SearchKind.project => Icons.grid_view_outlined,
  SearchKind.task => Icons.checklist_outlined,
  SearchKind.event => Icons.event_outlined,
  SearchKind.subscription => Icons.autorenew,
};
