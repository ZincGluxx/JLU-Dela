import 'package:flutter/material.dart';

import 'glass_surface.dart';
import 'theme.dart';

typedef AppPageBuilder = Widget Function(BuildContext context);

enum AppDestination {
  calendar('学习日历', '日历', Icons.calendar_month_outlined),
  teaching('课表', '课表', Icons.menu_book_outlined),
  assignments('作业', '作业', Icons.task_alt_outlined),
  materials('课程资料', '资料', Icons.folder_open_outlined),
  notices('校园通知', '通知', Icons.notifications_none_outlined),
  settings('设置与连接', '我的', Icons.tune_outlined);

  const AppDestination(this.label, this.shortLabel, this.icon);

  final String label;
  final String shortLabel;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.destination,
    required this.pages,
    required this.onDestinationSelected,
    this.glassEnabled = true,
  });

  final AppDestination destination;
  final Map<AppDestination, AppPageBuilder> pages;
  final ValueChanged<AppDestination> onDestinationSelected;
  final bool glassEnabled;

  static const mobileDestinations = [
    AppDestination.calendar,
    AppDestination.teaching,
    AppDestination.assignments,
    AppDestination.settings,
  ];

  static const moreDestinations = [
    AppDestination.materials,
    AppDestination.notices,
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _pageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDCEAFB), AppTheme.background, Color(0xFFECE5F7)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final page = KeyedSubtree(
                key: _pageKey,
                child: KeyedSubtree(
                  key: ValueKey(widget.destination),
                  child:
                      widget.pages[widget.destination]?.call(context) ??
                      _UnavailablePage(destination: widget.destination),
                ),
              );
              if (constraints.maxWidth >= AppBreakpoints.desktop) {
                return _DesktopLayout(
                  destination: widget.destination,
                  page: page,
                  glassEnabled: widget.glassEnabled,
                  sidebarWidth: constraints.maxWidth >= 1200 ? 224 : 184,
                  onDestinationSelected: widget.onDestinationSelected,
                );
              }
              return _MobileLayout(
                destination: widget.destination,
                page: page,
                glassEnabled: widget.glassEnabled,
                onDestinationSelected: widget.onDestinationSelected,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.destination,
    required this.page,
    required this.glassEnabled,
    required this.sidebarWidth,
    required this.onDestinationSelected,
  });

  final AppDestination destination;
  final Widget page;
  final bool glassEnabled;
  final double sidebarWidth;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            key: const Key('desktop-sidebar'),
            width: sidebarWidth,
            child: GlassSurface(
              enabled: glassEnabled,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: _Brand(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      '学习工作台',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      children: [
                        for (final item in AppDestination.values)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: _DestinationButton(
                              destination: item,
                              selected: destination == item,
                              onPressed: () => onDestinationSelected(item),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: _TopBar(
                  destination: destination,
                  glassEnabled: glassEnabled,
                  showBrand: false,
                  onDestinationSelected: onDestinationSelected,
                ),
              ),
              Expanded(child: _PageSurface(child: page)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.destination,
    required this.page,
    required this.glassEnabled,
    required this.onDestinationSelected,
  });

  final AppDestination destination;
  final Widget page;
  final bool glassEnabled;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: _TopBar(
            destination: destination,
            glassEnabled: glassEnabled,
            showBrand: true,
            onDestinationSelected: onDestinationSelected,
          ),
        ),
        Expanded(child: _PageSurface(child: page)),
        Padding(
          key: const Key('mobile-navigation'),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: GlassSurface(
            enabled: glassEnabled,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  for (final item in AppShell.mobileDestinations)
                    Expanded(
                      child: _DestinationButton(
                        destination: item,
                        selected: destination == item,
                        compact: true,
                        onPressed: () => onDestinationSelected(item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageSurface extends StatelessWidget {
  const _PageSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('app-page'),
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.destination,
    required this.glassEnabled,
    required this.showBrand,
    required this.onDestinationSelected,
  });

  final AppDestination destination;
  final bool glassEnabled;
  final bool showBrand;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final inMoreMenu = AppShell.moreDestinations.contains(destination);
    return GlassSurface(
      key: const Key('app-toolbar'),
      enabled: glassEnabled,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            if (showBrand) ...[
              const Flexible(child: _Brand()),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    if (!showBrand)
                      TextSpan(
                        text: '工作台 / ',
                        style: TextStyle(color: AppTheme.muted),
                      ),
                    TextSpan(text: destination.label),
                  ],
                ),
                key: const Key('app-page-title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (showBrand)
              PopupMenuButton<AppDestination>(
                key: const Key('mobile-more'),
                tooltip: '更多功能',
                initialValue: inMoreMenu ? destination : null,
                icon: Icon(
                  Icons.more_horiz,
                  color: inMoreMenu ? AppTheme.primary : null,
                ),
                onSelected: onDestinationSelected,
                itemBuilder: (context) => [
                  for (final item in AppShell.moreDestinations)
                    PopupMenuItem(value: item, child: Text(item.label)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
    this.compact = false,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(destination.icon, size: 20);
    final label = Text(
      compact ? destination.shortLabel : destination.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 11 : 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return Semantics(
      key: Key('destination-${destination.name}'),
      selected: selected,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: selected ? AppTheme.primary : AppTheme.muted,
          backgroundColor: selected
              ? AppTheme.blueSoft.withValues(alpha: 0.76)
              : Colors.transparent,
          alignment: compact ? Alignment.center : Alignment.centerLeft,
          padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
          minimumSize: compact ? const Size(48, 48) : const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.surfaceRadius),
          ),
        ),
        child: compact
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(height: AppSpacing.xs),
                  label,
                ],
              )
            : Row(
                children: [
                  icon,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: label),
                ],
              ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.near_me, color: AppTheme.primary, size: 28),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'Dela',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _UnavailablePage extends StatelessWidget {
  const _UnavailablePage({required this.destination});

  final AppDestination destination;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: 40, color: AppTheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(
              destination.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('此功能尚未开放', style: TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}
