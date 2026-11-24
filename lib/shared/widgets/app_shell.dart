import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/tokens.dart';
import '../../features/settings/application/settings_controller.dart';
import 'sync_banner.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.path, this.branch);

  final String label;
  final IconData icon;
  final String path;

  /// Índice de la rama en `StatefulShellRoute` (no siempre coincide con el
  /// orden visual del menú, porque Agenda y Perfil viven en el cajón lateral).
  final int branch;
}

const _destinations = [
  _Destination('Inicio', Icons.home_rounded, '/home', 0),
  _Destination('Proyectos', Icons.grid_view_rounded, '/projects', 1),
  _Destination('Agenda', Icons.calendar_month_rounded, '/agenda', 2),
  _Destination('Compartidos', Icons.groups_rounded, '/shared', 3),
  _Destination('Jardín', Icons.eco_rounded, '/garden', 4),
  _Destination('Perfil', Icons.person_rounded, '/profile', 5),
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
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(selectedIndex: selectedIndex),
                const VerticalDivider(width: 1),
                Expanded(child: _content(context, showBanner)),
              ],
            ),
          );
        }
        return Scaffold(
          key: _scaffoldKey,
          drawer: _AppDrawer(selectedIndex: selectedIndex),
          body: _content(context, showBanner),
          bottomNavigationBar: _MobileNav(
            selectedIndex: selectedIndex,
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
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
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.selectedIndex, required this.onMenu});

  final int selectedIndex;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final primary = _destinations.where((d) => d.branch != 2 && d.branch != 5);
    final menuSelected = selectedIndex == 2 || selectedIndex == 5;
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
                for (final destination in primary)
                  _NavItem(
                    destination: destination,
                    selected: destination.branch == selectedIndex,
                    onTap: () => _goTo(context, destination),
                  ),
                _NavItem(
                  destination: const _Destination(
                    'Menú',
                    Icons.menu_rounded,
                    '',
                    -1,
                  ),
                  selected: menuSelected,
                  onTap: onMenu,
                  semanticsLabel: 'Abrir menú',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.semanticsLabel,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final activeColor = p.navSelected;
    final inactiveColor = p.navInactive;
    final color = selected ? activeColor : inactiveColor;
    return Tooltip(
      message: semanticsLabel ?? destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticsLabel ?? destination.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: SizedBox(
            width: 64,
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
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = paletteFor(context);
    final profile = ref.watch(profileProvider).value;
    final name = profile?.displayName.trim() ?? '';
    final drawerDestinations = _destinations
        .where((d) => d.branch == 2 || d.branch == 5)
        .toList();

    void closeAnd(void Function() action) {
      Navigator.of(context).pop();
      action();
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Icon(Icons.eco_rounded, color: p.primary, size: 26),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    Brand.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Cerrar menú',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (name.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    if (profile?.email.isNotEmpty ?? false)
                      Text(
                        profile!.email,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: p.textSecondary),
                      ),
                  ],
                ),
              ),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            for (final destination in drawerDestinations)
              ListTile(
                selected: destination.branch == selectedIndex,
                selectedTileColor: p.primary.withValues(alpha: 0.08),
                leading: Icon(
                  destination.icon,
                  color: destination.branch == selectedIndex
                      ? p.primary
                      : p.navInactive,
                ),
                title: Text(
                  destination.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: destination.branch == selectedIndex
                        ? p.primary
                        : p.text,
                    fontWeight: destination.branch == selectedIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                onTap: () => closeAnd(() => _goTo(context, destination)),
              ),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _DrawerUtility(
              icon: Icons.search_rounded,
              label: 'Buscar',
              onTap: () => closeAnd(() => context.push('/search')),
            ),
            _DrawerUtility(
              icon: Icons.schedule_rounded,
              label: 'Tiempo',
              onTap: () => closeAnd(() => context.push('/time')),
            ),
            _DrawerUtility(
              icon: Icons.notifications_none_rounded,
              label: 'Notificaciones',
              onTap: () => closeAnd(() => context.push('/notifications')),
            ),
            _DrawerUtility(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () => closeAnd(() => context.push('/settings')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerUtility extends StatelessWidget {
  const _DrawerUtility({
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
    leading: Icon(icon, size: 20),
    title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    onTap: onTap,
  );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selectedIndex});

  final int selectedIndex;

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
                  selected: destination.branch == selectedIndex,
                  onTap: () => _goTo(context, destination),
                ),
              ),
            const Spacer(),
            const Divider(height: 1),
            _UtilityItem(
              icon: Icons.search,
              label: 'Buscar',
              onTap: () => context.push('/search'),
            ),
            _UtilityItem(
              icon: Icons.schedule,
              label: 'Tiempo',
              onTap: () => context.push('/time'),
            ),
            _UtilityItem(
              icon: Icons.notifications_none,
              label: 'Notificaciones',
              onTap: () => context.push('/notifications'),
            ),
            _UtilityItem(
              icon: Icons.settings_outlined,
              label: 'Ajustes',
              onTap: () => context.push('/settings'),
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

void _goTo(BuildContext context, _Destination destination) {
  context.go(destination.path);
}
