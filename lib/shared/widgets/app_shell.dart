import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/tokens.dart';
import 'sync_banner.dart';

/// Índices reales de `StatefulShellRoute.indexedStack` en `app_router.dart`.
/// La barra inferior móvil no los muestra tal cual: Agenda (índice 2) se
/// agrupa dentro de Menú, pero su rama y su ruta se conservan intactas.
abstract final class _Nav {
  static const home = 0;
  static const projects = 1;
  static const agenda = 2;
  static const shared = 3;
  static const garden = 4;
}

class _Destination {
  const _Destination(this.label, this.icon, this.path, this.branchIndex);

  final String label;
  final IconData icon;
  final String path;

  /// Índice de la rama en `StatefulShellRoute`; null si no es una rama.
  final int? branchIndex;
}

/// Mismo orden que las ramas declaradas en `app_router.dart`.
const _destinations = [
  _Destination(
    'Inicio',
    Icons.home_rounded,
    '/home',
    _Nav.home,
  ),
  _Destination(
    'Proyectos',
    Icons.grid_view_rounded,
    '/projects',
    _Nav.projects,
  ),
  _Destination('Agenda', Icons.calendar_month_rounded, '/agenda', _Nav.agenda),
  _Destination('Compartidos', Icons.groups_rounded, '/shared', _Nav.shared),
  _Destination('Jardín', Icons.eco_rounded, '/garden', _Nav.garden),
];

/// Posiciones visibles en la barra inferior móvil. Menú no es una rama: es la
/// acción que abre el Drawer y representa también el grupo que contiene Agenda.
const _mobileBranchIndexes = [
  _Nav.home,
  _Nav.projects,
  _Nav.shared,
  _Nav.garden,
];

const _menuDestination = _Destination('Menú', Icons.menu_rounded, '', null);

/// Contenido del Drawer móvil. Las rutas ya existen en el router.
const _drawerDestinations = [
  _Destination('Agenda', Icons.calendar_month_rounded, '/agenda', _Nav.agenda),
  _Destination('Buscar', Icons.search_rounded, '/search', null),
  _Destination('Tiempo', Icons.schedule_rounded, '/time', null),
  _Destination(
    'Notificaciones',
    Icons.notifications_none_rounded,
    '/notifications',
    null,
  ),
  _Destination('Configuración', Icons.settings_outlined, '/settings', null),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final store = ref.watch(localStoreProvider).value;
    final pending = store?.pending().length ?? 0;
    final conflicts = store?.conflicts().length ?? 0;
    final showBanner = !online || pending > 0 || conflicts > 0;
    final selectedIndex = widget.navigationShell.currentIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(
                  selectedIndex: selectedIndex,
                  onDestination: widget.navigationShell.goBranch,
                  onRoute: (path) => _pushOnce(context, path),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _content(context, showBanner)),
              ],
            ),
          );
        }

        final drawerWidth = (constraints.maxWidth - 48)
            .clamp(220.0, 320.0)
            .toDouble();
        return Scaffold(
          key: _scaffoldKey,
          drawer: _AppMenuDrawer(
            width: drawerWidth,
            currentIndex: selectedIndex,
            onAgenda: () => widget.navigationShell.goBranch(_Nav.agenda),
            onRoute: (path) => _pushOnce(context, path),
          ),
          body: _content(context, showBanner),
          bottomNavigationBar: _PillNav(
            selectedIndex: selectedIndex,
            onBranchSelected: widget.navigationShell.goBranch,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, bool showBanner) {
    // El aviso ya reserva el padding superior del sistema. Quitar ese inset al
    // contenido evita que cada pantalla vuelva a añadirlo en tamaño móvil.
    final content = showBanner
        ? MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.navigationShell,
          )
        : widget.navigationShell;
    return Column(
      children: [
        SyncBanner(visible: showBanner),
        Expanded(child: content),
      ],
    );
  }

  /// Las opciones secundarias viven fuera del shell; `push` conserva el estado
  /// de las ramas al volver. El guardián evita apilar la misma ruta dos veces.
  void _pushOnce(BuildContext context, String path) {
    if (GoRouterState.of(context).uri.path == path) return;
    context.push(path);
  }
}

class _PillNav extends StatelessWidget {
  const _PillNav({
    required this.selectedIndex,
    required this.onBranchSelected,
    required this.onMenuTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 8),
        child: Semantics(
          label: 'Navegación principal',
          child: SizedBox(
            height: 56,
            key: const Key('mobile-nav-bar'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final index in _mobileBranchIndexes)
                  Expanded(
                    child: _PillItem(
                      destination: _destinations[index],
                      selected: index == selectedIndex,
                      onTap: () {
                        if (index != selectedIndex) onBranchSelected(index);
                      },
                    ),
                  ),
                Expanded(
                  child: _PillItem(
                    destination: _menuDestination,
                    selected: selectedIndex == _Nav.agenda,
                    tooltipLabel: 'Abrir menú',
                    onTap: onMenuTap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  const _PillItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.tooltipLabel,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltipLabel;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final activeColor = p.navSelected;
    final inactiveColor = p.navInactive;
    final color = selected ? activeColor : inactiveColor;
    return Tooltip(
      message: tooltipLabel ?? destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(destination.icon, size: 20, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drawer modal del shell móvil: superpone el contenido, respeta SafeArea y
/// usa el mismo sistema visual que el sidebar.
class _AppMenuDrawer extends StatelessWidget {
  const _AppMenuDrawer({
    required this.width,
    required this.currentIndex,
    required this.onAgenda,
    required this.onRoute,
  });

  final double width;
  final int currentIndex;
  final VoidCallback onAgenda;
  final ValueChanged<String> onRoute;

  void _close(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  void _selectAgenda(BuildContext context) {
    _close(context);
    if (currentIndex != _Nav.agenda) onAgenda();
  }

  void _selectRoute(BuildContext context, String path) {
    _close(context);
    onRoute(path);
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final theme = Theme.of(context);
    return DrawerTheme(
      data: DrawerThemeData(
        width: width,
        backgroundColor: p.surface,
        scrimColor: p.scrim,
        elevation: 12,
        shadowColor: p.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            right: Radius.circular(AppRadius.md),
          ),
        ),
      ),
      child: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Icon(Icons.eco_rounded, color: p.primary, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Menú', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Cerrar menú',
                      icon: const Icon(Icons.close),
                      onPressed: () => _close(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: [
                    for (final item in _drawerDestinations)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        child: _SidebarItem(
                          destination: item,
                          selected:
                              item.branchIndex == _Nav.agenda &&
                              currentIndex == _Nav.agenda,
                          onTap: () {
                            if (item.branchIndex == _Nav.agenda) {
                              _selectAgenda(context);
                            } else {
                              _selectRoute(context, item.path);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onDestination,
    required this.onRoute,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestination;
  final ValueChanged<String> onRoute;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final theme = Theme.of(context);
    return Container(
      width: 240,
      color: p.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              child: Row(
                children: [
                  Icon(Icons.eco_rounded, color: p.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Text(Brand.name, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
            for (final destination in _destinations)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                child: _SidebarItem(
                  destination: destination,
                  selected: destination.branchIndex == selectedIndex,
                  onTap: () => onDestination(destination.branchIndex!),
                ),
              ),
            const Spacer(),
            const Divider(height: 1),
            _UtilityItem(
              icon: Icons.search_rounded,
              label: 'Buscar',
              onTap: () => onRoute('/search'),
            ),
            _UtilityItem(
              icon: Icons.schedule_rounded,
              label: 'Tiempo',
              onTap: () => onRoute('/time'),
            ),
            _UtilityItem(
              icon: Icons.notifications_none_rounded,
              label: 'Notificaciones',
              onTap: () => onRoute('/notifications'),
            ),
            _UtilityItem(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () => onRoute('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return Semantics(
      selected: selected,
      child: ListTile(
        selected: selected,
        selectedColor: p.primary,
        leading: Icon(destination.icon, size: 20),
        title: Text(
          destination.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _UtilityItem extends StatelessWidget {
  const _UtilityItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon, size: 19),
    title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    onTap: onTap,
  );
}
