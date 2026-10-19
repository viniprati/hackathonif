import 'package:flutter/material.dart';

class NativaColors {
  static const darkGreen = Color(0xFF234631);
  static const green = Color(0xFF2F593D);
  static const earth = Color(0xFF70452D);
  static const lightGreen = Color(0xFFDCE8D2);
  static const cream = Color(0xFFF7F3E8);
  static const gray = Color(0xFF454545);
  static const border = Color(0xFFC9C9C2);
  static const yellow = Color(0xFFF2C14E);
  static const terracotta = Color(0xFFA65335);
}

ThemeData nativaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NativaColors.green,
    primary: NativaColors.green,
    surface: NativaColors.cream,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NativaColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: NativaColors.cream,
      foregroundColor: NativaColors.darkGreen,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NativaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NativaColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}

class NativaBrand extends StatelessWidget {
  const NativaBrand({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/nativa_logo.png',
            width: large ? 105 : 60,
            height: large ? 85 : 50,
            fit: BoxFit.contain,
            semanticLabel: 'Logo Nativa',
          ),
          Text(
            'Nativa',
            style: TextStyle(
              fontSize: large ? 38 : 28,
              fontWeight: FontWeight.w700,
              color: NativaColors.earth,
              height: 1,
            ),
          ),
        ],
      );
}

String formatKg(double value) =>
    '${value.toStringAsFixed(1).replaceAll('.', ',')} kg';

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

const monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
