import 'package:flutter/services.dart';

String cpfDigits(String value) => value.replaceAll(RegExp(r'\D'), '');

/// Mantém a posição do cursor em relação aos números ao inserir pontuação.
class CpfFormatter extends TextInputFormatter {
  const CpfFormatter();
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (!newValue.composing.isCollapsed) return newValue;
    var digits = cpfDigits(newValue.text);
    if (digits.length > 11) digits = digits.substring(0, 11);
    final result = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) result.write('.');
      if (i == 9) result.write('-');
      result.write(digits[i]);
    }
    final formatted = result.toString();
    int offset(int original) {
      if (original < 0) return formatted.length;
      final count = cpfDigits(newValue.text
              .substring(0, original.clamp(0, newValue.text.length)))
          .length
          .clamp(0, digits.length);
      var found = 0;
      for (var i = 0; i < formatted.length; i++) {
        if (RegExp(r'\d').hasMatch(formatted[i])) found++;
        if (found == count) return count == 0 ? 0 : i + 1;
      }
      return formatted.length;
    }

    return TextEditingValue(
        text: formatted,
        selection: TextSelection(
            baseOffset: offset(newValue.selection.baseOffset),
            extentOffset: offset(newValue.selection.extentOffset)));
  }
}
