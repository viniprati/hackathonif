import 'package:flutter/material.dart';

/// Combines the reader's preference with the system's text scaling curve.
class ReaderTextScaler extends TextScaler {
  const ReaderTextScaler(this.system, this.multiplier);

  final TextScaler system;
  final double multiplier;

  @override
  double scale(double fontSize) => system.scale(fontSize) * multiplier;

  @override
  double get textScaleFactor => scale(14) / 14;
}

class TextSizeControls extends StatelessWidget {
  const TextSizeControls({
    super.key,
    required this.step,
    required this.onChanged,
    this.onAccessibility,
  });

  final VoidCallback? onAccessibility;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                if (onAccessibility != null)
                  IconButton(
                      tooltip: 'Acessibilidade',
                      onPressed: onAccessibility,
                      icon: const Icon(Icons.accessibility_new)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Letras'),
                ),
                IconButton(
                  tooltip: 'Diminuir letras',
                  onPressed: step > 0 ? () => onChanged(step - 1) : null,
                  icon: const Icon(Icons.text_decrease),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                Semantics(
                  liveRegion: true,
                  label: 'Tamanho das letras: ${100 + step * 20}% do aparelho',
                  child: ExcludeSemantics(child: Text('${100 + step * 20}%')),
                ),
                IconButton(
                  tooltip: 'Aumentar letras',
                  onPressed: step < 5 ? () => onChanged(step + 1) : null,
                  icon: const Icon(Icons.text_increase),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                IconButton(
                  tooltip: 'Restaurar tamanho das letras do aparelho',
                  onPressed: step > 0 ? () => onChanged(0) : null,
                  icon: const Icon(Icons.restart_alt),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ],
            ),
          ),
        ),
      );
}
