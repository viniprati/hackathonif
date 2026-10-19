import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'delivery_screen.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.viewModel, required this.onSignOut});
  final DeliveryViewModel viewModel;
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final pages = [
            HomeScreen(
              viewModel: widget.viewModel,
              openDeliveries: () => setState(() => _index = 1),
            ),
            DeliveryScreen(viewModel: widget.viewModel),
            DocumentsScreen(viewModel: widget.viewModel),
            ProfileScreen(onSignOut: widget.onSignOut),
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
              label: 'Entregas',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Documentos',
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
                          label: Text('Entregas'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.description_outlined),
                          selectedIcon: Icon(Icons.description),
                          label: Text('Documentos'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('Perfil'),
                        ),
                      ],
                    ),
                  Expanded(child: pages[_index]),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (index) =>
                        setState(() => _index = index),
                    destinations: destinations,
                  ),
          );
        },
      );
}

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key, required this.viewModel});
  final DeliveryViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Documentos',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('Resumo dos lotes cadastrados neste protótipo.'),
                const SizedBox(height: 20),
                ...viewModel.deliveries.map(
                  (delivery) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: NativaColors.lightGreen,
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: NativaColors.darkGreen,
                        ),
                      ),
                      title: Text('Lote #${delivery.id} • ${delivery.product}'),
                      subtitle: Text(
                        '${formatDate(delivery.date)}  •  ${delivery.schoolCount} escolas  •  ${formatKg(delivery.distributedKg)}',
                      ),
                      trailing: Icon(
                        delivery.status == DeliveryStatus.completed
                            ? Icons.check_circle
                            : Icons.schedule,
                        color: delivery.status == DeliveryStatus.completed
                            ? NativaColors.green
                            : NativaColors.terracotta,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Comprovantes assinados e exportação serão incluídos quando houver armazenamento e contas reais.',
                    style: TextStyle(color: NativaColors.gray),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onSignOut});
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
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
                    ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Versão'),
                      subtitle: Text('Protótipo 0.1.0'),
                    ),
                  ],
                ),
              ),
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
