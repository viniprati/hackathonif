import 'package:flutter/material.dart';

/// Valida e leva a leitura e o teclado ao primeiro erro na ordem do formulário.
bool validateAccessibleForm(GlobalKey<FormState> key) {
  final invalid = key.currentState!.validateGranularly();
  if (invalid.isEmpty) return true;
  final field = invalid.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!field.mounted) return;
    FocusNode? focus;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is EditableText) focus ??= widget.focusNode;
      if (widget is Focus && widget.focusNode != null) {
        focus ??= widget.focusNode;
      }
      element.visitChildren(visit);
    }

    field.context.visitChildElements(visit);
    focus?.requestFocus();
    Scrollable.ensureVisible(field.context,
        alignment: .15, duration: const Duration(milliseconds: 250));
  });
  return false;
}

class GuidanceMessage extends StatelessWidget {
  const GuidanceMessage(this.message, {super.key, this.error = true});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
                child: Icon(error ? Icons.error_outline : Icons.info_outline,
                    color: error
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurface)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: TextStyle(
                        color: error
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurface))),
          ])));
}

/// O card inteiro é um botão único, com seus textos lidos na sequência visual.
class AccessibleInkWell extends StatelessWidget {
  const AccessibleInkWell(
      {super.key,
      required this.child,
      this.onTap,
      this.borderRadius,
      this.excludeFromSemantics = false});
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool excludeFromSemantics;
  @override
  Widget build(BuildContext context) => MergeSemantics(
      child: Semantics(
          button: true,
          enabled: onTap != null,
          child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              excludeFromSemantics: excludeFromSemantics,
              child: child)));
}

Future<bool> confirmDiscard(BuildContext context,
        {required String title,
        required String consequence,
        required String action}) async =>
    await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: Text(title),
                content: Text(consequence),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(action)),
                ])) ??
    false;

class AccessibleHeading extends StatelessWidget {
  const AccessibleHeading(this.text, {super.key, this.style, this.textAlign});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Semantics(
      header: true, child: Text(text, style: style, textAlign: textAlign));
}
