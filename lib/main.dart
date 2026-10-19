import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/delivery_repository.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';
import 'ui/view_models/delivery_view_model.dart';

void main() => runApp(const NativaApp());

class NativaApp extends StatefulWidget {
  const NativaApp({super.key});

  @override
  State<NativaApp> createState() => _NativaAppState();
}

class _NativaAppState extends State<NativaApp> {
  late final DeliveryViewModel _viewModel = DeliveryViewModel(
    DeliveryRepository(),
  );
  bool _signedIn = false;

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Nativa',
        debugShowCheckedModeBanner: false,
        theme: nativaTheme(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: _signedIn
            ? AppShell(
                viewModel: _viewModel,
                onSignOut: () => setState(() => _signedIn = false),
              )
            : LoginScreen(onSignIn: () => setState(() => _signedIn = true)),
      );
}
