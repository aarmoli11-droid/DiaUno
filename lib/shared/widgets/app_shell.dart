import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/brand.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/tokens.dart';
import 'sync_banner.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const _destinations = [
  _Destination('Inicio', Icons.home_outlined, '/home'),
  _Destination('Proyectos', Icons.grid_view_outlined, '/projects'),
  _Destination('Agenda', Icons.calendar_month_outlined, '/agenda'),
  _Destination('Compartidos', Icons.groups_outlined, '/shared'),
  _Destination('Jardín', Icons.eco_outlined, '/garden'),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Sidebar(selectedIndex: navigationShell.currentIndex),
                const VerticalDivider(width: 1),
                Expanded(child: _content()),
              ],
            ),
          );
        }
        return Scaffold(
          body: _content(),
          bottomNavigationBar: _PillNav(
            selectedIndex: navigationShell.currentIndex,
          ),
        );
      },
    );
  }

  Widget _content() {
    return Column(
      children: [
        const SyncBanner(),
        Expanded(child: navigationShell),
      ],
    );
  }
}

class _PillNav extends StatelessWidget {
  const _PillNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Semantics(
          label: 'Navegación principal',
          child: Container(
            height: 66,
            constraints: const BoxConstraints(maxWidth: AppSpacing.navMaxWidth),
            decoration: BoxDecoration(
              color: p.navBackground,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: [
                BoxShadow(
                  color: p.scrim.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: _PillItem(
                      destination: _destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => _go(context, i),
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
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(context);
    final activeColor = p.onPrimary;
    final inactiveColor = p.navInactive;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: 2,
          ),
          decoration: BoxDecoration(
            color: selected ? p.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                destination.icon,
                size: 20,
                color: selected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 3),
              Text(
                destination.label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeColor : inactiveColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(2),
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
            for (var i = 0; i < _destinations.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                child: _SidebarItem(
                  destination: _destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => _go(context, i),
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

void _go(BuildContext context, int index) {
  context.go(_destinations[index].path);
}
