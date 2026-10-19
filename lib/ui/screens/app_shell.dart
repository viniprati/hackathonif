import 'package:flutter/material.dart';

import '../theme.dart';
import '../view_models/delivery_view_model.dart';
import 'batch_screen.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';

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
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 18.2;
          final pages = [
            HomeScreen(
              viewModel: widget.viewModel,
              openBatches: () => setState(() => _index = 1),
            ),
            BatchesScreen(viewModel: widget.viewModel),
            ProductsScreen(viewModel: widget.viewModel),
            ReportsScreen(viewModel: widget.viewModel),
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
                  Expanded(child: pages[_index]),
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
                      subtitle: Text('Versão 1.0.4'),
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
