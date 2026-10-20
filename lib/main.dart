import 'dart:async';
import 'package:flutter/material.dart';
import 'data/accessibility_settings.dart';
import 'ui/accessibility_settings_panel.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/auth_repository.dart';
import 'data/batch_api.dart';
import 'data/manual_sync.dart';
import 'data/sync_store.dart';
import 'data/delivery_repository.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';
import 'ui/text_size_controls.dart';
import 'ui/view_models/auth_view_model.dart';
import 'ui/view_models/delivery_view_model.dart';

void main() => runApp(const NativaApp());

class NativaApp extends StatefulWidget {
  const NativaApp(
      {super.key,
      this.authRepository,
      this.deliveryRepository,
      this.syncStore,
      this.accessibilityStore});
  final DeliveryRepository? deliveryRepository;
  final SyncStore? syncStore;
  final SyncStore? accessibilityStore;
  final AuthRepository? authRepository;

  @override
  State<NativaApp> createState() => _NativaAppState();
}

class _NativaAppState extends State<NativaApp> {
  late final AuthRepository _authRepository =
      widget.authRepository ?? AuthRepository();
  late final DeliveryRepository _repository =
      widget.deliveryRepository ?? DeliveryRepository(withExamples: false);
  late final AuthViewModel _auth = AuthViewModel(_authRepository);
  late final DeliveryViewModel _viewModel = DeliveryViewModel(_repository,
      sync: ManualSync(
          repository: _repository,
          api: BatchApi(_authRepository),
          store: widget.syncStore ??
              PreferencesSyncStore(_authRepository.apiUrl)));
  late Future<void> _ready = _viewModel.initialize();
  int _textSizeStep = 0;
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AccessibilitySettings _accessibility = AccessibilitySettings(
      widget.accessibilityStore ?? PreferencesSyncStore.accessibility());
  @override
  void initState() {
    super.initState();
    unawaited(_accessibility.load());
  }

  void _showAccessibility() {
    final context = _navigatorKey.currentState?.overlay?.context;
    if (context == null) return;
    showDialog<void>(
        context: context,
        builder: (context) =>
            AlertDialog(
                scrollable: true,
                title: const Text('Preferências de leitura'),
                content: SizedBox(
                    width: 440,
                    child:
                        AccessibilitySettingsPanel(settings: _accessibility)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'))
                ]));
  }

  @override
  void dispose() {
    _accessibility.dispose();
    _viewModel.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccessibilityScope(
      settings: _accessibility,
      child: ListenableBuilder(
          listenable: _accessibility,
          builder: (context, _) => MaterialApp(
                navigatorKey: _navigatorKey,
                title: 'Nativa',
                debugShowCheckedModeBanner: false,
                theme: nativaTheme(highContrast: _accessibility.highContrast),
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return Overlay.wrap(
                    child: Column(
                      children: [
                        TextSizeControls(
                          step: _textSizeStep,
                          onAccessibility: _showAccessibility,
                          onChanged: (step) =>
                              setState(() => _textSizeStep = step),
                        ),
                        Expanded(
                          child: MediaQuery(
                            data: media.copyWith(
                              padding: media.padding.copyWith(top: 0),
                              textScaler: ReaderTextScaler(
                                media.textScaler,
                                1 + _textSizeStep * 0.2,
                              ),
                            ),
                            child: child!,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                locale: const Locale('pt', 'BR'),
                supportedLocales: const [Locale('pt', 'BR')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: ListenableBuilder(
                  listenable: _auth,
                  builder: (context, _) => _auth.isAuthenticated
                      ? FutureBuilder<void>(
                          future: _ready,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Scaffold(
                                  body: Center(
                                      child: CircularProgressIndicator()));
                            }
                            if (snapshot.hasError) {
                              return Scaffold(
                                  body: Center(
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                    const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                            'Não foi possível abrir os dados do aparelho. A cópia existente foi preservada.')),
                                    const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24),
                                        child: Text(
                                            'Tente novamente. Se o problema continuar, peça ajuda à equipe para recuperar a cópia existente.')),
                                    FilledButton(
                                        onPressed: () => setState(() {
                                              _ready = _viewModel.initialize();
                                            }),
                                        child: const Text('Tentar novamente')),
                                    TextButton(
                                        onPressed: _auth.signOut,
                                        child: const Text('Sair')),
                                  ])));
                            }
                            return AppShell(
                                viewModel: _viewModel,
                                onSignOut: _auth.signOut);
                          })
                      : LoginScreen(viewModel: _auth),
                ),
              )));
}
