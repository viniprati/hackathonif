import 'package:flutter/material.dart';
import '../data/accessibility_settings.dart';
import 'accessibility_widgets.dart';

class AccessibilityScope extends InheritedNotifier<AccessibilitySettings> {
  const AccessibilityScope(
      {super.key,
      required AccessibilitySettings settings,
      required super.child})
      : super(notifier: settings);
  static AccessibilitySettings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AccessibilityScope>()
      ?.notifier;
}

class AccessibilitySettingsPanel extends StatelessWidget {
  const AccessibilitySettingsPanel({super.key, required this.settings});
  final AccessibilitySettings settings;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                    header: true,
                    child: const Text('Acessibilidade',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Alto contraste'),
                    subtitle: const Text(
                        'Realça textos, contornos e controles para facilitar a leitura.'),
                    value: settings.highContrast,
                    onChanged: settings.loaded && !settings.busy
                        ? settings.setHighContrast
                        : null),
                const Text(
                    'Use os botões de letras no topo para aumentar, diminuir ou restaurar o tamanho do aparelho.'),
                if (settings.busy)
                  const Padding(
                      padding: EdgeInsets.all(8),
                      child: LinearProgressIndicator(
                          semanticsLabel:
                              'Salvando configuração de acessibilidade')),
                if (settings.message != null) ...[
                  GuidanceMessage(settings.message!),
                  OutlinedButton(
                      onPressed: settings.busy
                          ? null
                          : () => settings.loaded
                              ? settings.setHighContrast(!settings.highContrast)
                              : settings.load(),
                      child: const Text('Tentar novamente')),
                ],
              ]));
}
