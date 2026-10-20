import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/auth_repository.dart';
import 'data/delivery_repository.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';
import 'ui/text_size_controls.dart';
import 'ui/view_models/auth_view_model.dart';
import 'ui/view_models/delivery_view_model.dart';

void main() => runApp(const NativaApp());

class NativaApp extends StatefulWidget {
  const NativaApp({super.key, this.authRepository});
  final AuthRepository? authRepository;

  @override
  State<NativaApp> createState() => _NativaAppState();
}

class _NativaAppState extends State<NativaApp> {
  late final DeliveryViewModel _viewModel = DeliveryViewModel(
    DeliveryRepository(),
  );
  late final AuthViewModel _auth = AuthViewModel(
    widget.authRepository ?? AuthRepository(),
  );
  int _textSizeStep = 0;

  @override
  void dispose() {
    _viewModel.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nativa',
        debugShowCheckedModeBanner: false,
        theme: nativaTheme(),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return Overlay.wrap(
            child: Column(
              children: [
                TextSizeControls(
                  step: _textSizeStep,
                  onChanged: (step) => setState(() => _textSizeStep = step),
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
              ? AppShell(viewModel: _viewModel, onSignOut: _auth.signOut)
              : LoginScreen(viewModel: _auth),
        ),
      );
}
