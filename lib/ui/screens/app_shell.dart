import '../../data/push_subscription.dart';
import 'dart:async';
import '../../data/auth_repository.dart';
import '../../data/notifications.dart';
import '../../data/sync_store.dart';
import '../notifications_panel.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../accessibility_settings_panel.dart';
import '../sync_card.dart';
import '../app_version_tile.dart';
import '../view_models/delivery_view_model.dart';
import 'batch_screen.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell(
      {super.key,
      required this.viewModel,
      required this.onSignOut,
      this.authRepository,
      this.notificationStore});
  final AuthRepository? authRepository;
  final SyncStore? notificationStore;
  final DeliveryViewModel viewModel;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  NotificationCenter? _notifications;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = widget.authRepository;
    if (auth != null) {
      _notifications = NotificationCenter(
          auth,
          widget.notificationStore ??
              PreferencesSyncStore.notifications(auth.apiUrl),
          push: AndroidPushSubscription(auth, onNotice: () {
            if (!mounted) return;
            unawaited(_notifications?.refresh());
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                duration: const Duration(seconds: 12),
                content: const Text('Há um novo aviso de montante.'),
                action: SnackBarAction(
                    label: 'Ver avisos', onPressed: _openNotifications)));
          }, onOpen: () {
            if (mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _openNotifications();
              });
            }
          }, onError: (message) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(message)));
            }
          }));
      unawaited(_notifications!.initialize());
      widget.viewModel.sync?.addListener(_afterSync);
    }
  }

  Future<void> _signOut() async {
    final allowed = await _notifications?.prepareSignOut() ?? true;
    if (!mounted) return;
    if (allowed) {
      widget.onSignOut();
    } else {
      _openNotifications();
    }
  }

  void _afterSync() {
    if (widget.viewModel.sync?.busy == false) {
      unawaited(_notifications?.refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _notifications?.foreground(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.viewModel.sync?.removeListener(_afterSync);
    _notifications?.dispose();
    super.dispose();
  }

  void _openNotifications() {
    final center = _notifications;
    if (center == null) return;
    unawaited(center.refresh(force: true));
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Avisos de montantes'),
              content: SizedBox(
                  width: 560, child: NotificationsPanel(center: center)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'))
              ],
            ));
  }

  int _index = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;
          final pages = [
            HomeScreen(
              viewModel: widget.viewModel,
              openBatches: () => setState(() => _index = 1),
            ),
            BatchesScreen(viewModel: widget.viewModel),
            ProductsScreen(viewModel: widget.viewModel),
            ReportsScreen(viewModel: widget.viewModel),
            ProfileScreen(
                viewModel: widget.viewModel,
                onSignOut: _signOut,
                notifications: _notifications),
          ];
          final destinations = const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_shipping_outlined),
              selectedIcon: Icon(Icons.local_shipping),
              label: 'Montantes',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Produtos',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Relatórios',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ];
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      scrollable: true,
                      selectedIndex: _index,
                      onDestinationSelected: (index) =>
                          setState(() => _index = index),
                      labelType: NavigationRailLabelType.all,
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: NativaBrand(),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Início'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.local_shipping_outlined),
                          selectedIcon: Icon(Icons.local_shipping),
                          label: Text('Montantes'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2),
                          label: Text('Produtos'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.description_outlined),
                          selectedIcon: Icon(Icons.description),
                          label: Text('Relatórios'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('Perfil'),
                        ),
                      ],
                    ),
                  Expanded(
                      child: Column(children: [
                    if (_notifications case final center?)
                      Align(
                          alignment: Alignment.centerRight,
                          child: ListenableBuilder(
                              listenable: center,
                              builder: (context, _) => TextButton.icon(
                                  onPressed: _openNotifications,
                                  icon:
                                      const Icon(Icons.notifications_outlined),
                                  label: Text(
                                      'Avisos${center.unread > 0 ? ' (${center.unread} não lidos)' : ''}')))),
                    Expanded(child: pages[_index]),
                  ])),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : largeText
                    ? SafeArea(
                        top: false,
                        child: PopupMenuButton<int>(
                          tooltip: 'Navegar entre páginas',
                          onSelected: (index) => setState(() => _index = index),
                          itemBuilder: (_) => [
                            for (var i = 0; i < destinations.length; i++)
                              PopupMenuItem(
                                value: i,
                                child: Text(destinations[i].label),
                              ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.menu),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        'Navegar: ${destinations[_index].label}')),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ),
                      )
                    : AccessibleBottomNavigation(
                        selectedIndex: _index,
                        onSelected: (index) => setState(() => _index = index),
                        destinations: destinations,
                      ),
          );
        },
      );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen(
      {super.key,
      required this.onSignOut,
      required this.viewModel,
      this.notifications});
  final DeliveryViewModel viewModel;
  final VoidCallback onSignOut;
  final NotificationCenter? notifications;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const AccessibleHeading(
                'Perfil',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: NativaColors.lightGreen,
                        child: Icon(
                          Icons.person,
                          size: 36,
                          color: NativaColors.darkGreen,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Seu José',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text('Aprovista • Distribuição de alimentos'),
                    ],
                  ),
                ),
              ),
              if (AccessibilityScope.maybeOf(context) case final settings?) ...[
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AccessibilitySettingsPanel(settings: settings))),
              ],
              const SizedBox(height: 12),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.groups_outlined),
                      title: Text('Associação'),
                      subtitle: Text('Aprovista'),
                    ),
                    Divider(height: 1),
                    AppVersionTile(),
                  ],
                ),
              ),
              if (viewModel.sync != null) ...[
                const SizedBox(height: 16),
                SyncCard(sync: viewModel.sync!, onSessionExpired: onSignOut),
              ],
              if (notifications case final center?) ...[
                const SizedBox(height: 16),
                Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AccessibleHeading('Notificações',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              NotificationsPanel(center: center)
                            ]))),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      );
}

/// Não divide rótulos em palavras; usa rolagem quando a fonte exige mais espaço.
class AccessibleBottomNavigation extends StatelessWidget {
  const AccessibleBottomNavigation(
      {super.key,
      required this.selectedIndex,
      required this.onSelected,
      required this.destinations});
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        child: SafeArea(
            top: false,
            child: LayoutBuilder(builder: (context, constraints) {
              final style = Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .copyWith(fontSize: 12, letterSpacing: 0);
              final widths = destinations.map((d) {
                final painter = TextPainter(
                    text: TextSpan(text: d.label, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context))
                  ..layout();
                final width = painter.width + 12;
                painter.dispose();
                return width;
              });
              final minimum = widths.fold<double>(64, (a, b) => a > b ? a : b);
              final width = (constraints.maxWidth / destinations.length)
                  .clamp(minimum, double.infinity);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                if (minimum * destinations.length > constraints.maxWidth)
                  const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Deslize a barra para ver mais opções',
                          style: TextStyle(fontSize: 12))),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (var i = 0; i < destinations.length; i++)
                      SizedBox(
                          width: width,
                          child: Semantics(
                              selected: selectedIndex == i,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 12)),
                                onPressed: () => onSelected(i),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: selectedIndex == i
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(24)),
                                          child: IconTheme(
                                              data: IconThemeData(
                                                  color: selectedIndex == i
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurface),
                                              child: selectedIndex == i
                                                  ? destinations[i]
                                                          .selectedIcon ??
                                                      destinations[i].icon
                                                  : destinations[i].icon)),
                                      const SizedBox(height: 4),
                                      Text(destinations[i].label,
                                          style: style,
                                          softWrap: false,
                                          maxLines: 1),
                                    ]),
                              ))),
                  ]),
                ),
              ]);
            })),
      );
}
