import 'package:flutter/material.dart';
export 'accessibility_widgets.dart';

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

class AccessibilityTheme extends ThemeExtension<AccessibilityTheme> {
  const AccessibilityTheme(this.highContrast);
  final bool highContrast;
  @override
  AccessibilityTheme copyWith({bool? highContrast}) =>
      AccessibilityTheme(highContrast ?? this.highContrast);
  @override
  AccessibilityTheme lerp(covariant AccessibilityTheme? other, double t) =>
      t < .5 ? this : other ?? this;
}

bool highContrastOf(BuildContext context) =>
    Theme.of(context).extension<AccessibilityTheme>()?.highContrast ?? false;

// WCAG: luminância relativa sRGB; usado também para testar a paleta renderizada.
double contrastRatio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
}

ThemeData nativaTheme({bool highContrast = false}) {
  final foreground = highContrast ? Colors.black : NativaColors.darkGreen;
  final background = highContrast ? Colors.white : NativaColors.cream;
  final primary = highContrast ? Colors.black : NativaColors.green;
  final error =
      highContrast ? const Color(0xFF800000) : const Color(0xFF9C1C23);
  final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    surface: background,
    onSurface: Colors.black,
    onSurfaceVariant: highContrast ? Colors.black : NativaColors.gray,
    primaryContainer: highContrast ? Colors.black : NativaColors.lightGreen,
    onPrimaryContainer: highContrast ? Colors.white : NativaColors.darkGreen,
    secondaryContainer: highContrast ? Colors.black : NativaColors.lightGreen,
    onSecondaryContainer: highContrast ? Colors.white : NativaColors.darkGreen,
    error: error,
    onError: Colors.white,
    errorContainer: const Color(0xFFFFEDEE),
    onErrorContainer: error,
    outline: highContrast ? Colors.black : NativaColors.gray,
  );
  OutlineInputBorder border(Color color, [double width = 1.5]) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width));
  ButtonStyle button(Color bg, Color fg) => ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? const Color(0xFFE5E5E5)
                : bg),
        foregroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.disabled)
                ? const Color(0xFF454545)
                : fg),
        side: WidgetStatePropertyAll(BorderSide(
            color: highContrast ? Colors.black : primary,
            width: highContrast ? 2 : 1)),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    extensions: [AccessibilityTheme(highContrast)],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: background,
    disabledColor: const Color(0xFF555555),
    focusColor:
        highContrast ? const Color(0xFFB0D8FF) : const Color(0xFFB8D0AF),
    textTheme:
        base.textTheme.apply(bodyColor: Colors.black, displayColor: foreground),
    appBarTheme:
        AppBarTheme(backgroundColor: background, foregroundColor: foreground),
    cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: highContrast ? 0 : 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: highContrast
                ? const BorderSide(color: Colors.black, width: 2)
                : BorderSide.none)),
    dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: highContrast
                ? const BorderSide(color: Colors.black, width: 2)
                : BorderSide.none)),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(color: foreground),
        hintStyle: const TextStyle(color: NativaColors.gray),
        helperStyle: const TextStyle(color: NativaColors.gray),
        errorStyle: TextStyle(color: error),
        errorMaxLines: 6,
        helperMaxLines: 4,
        border: border(scheme.outline),
        enabledBorder: border(scheme.outline),
        disabledBorder: border(const Color(0xFF555555)),
        focusedBorder: border(primary, 3),
        errorBorder: border(error, 2),
        focusedErrorBorder: border(error, 3)),
    filledButtonTheme:
        FilledButtonThemeData(style: button(primary, Colors.white)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: button(Colors.white, primary)),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: primary,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: foreground,
            disabledForegroundColor: const Color(0xFF555555))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: foreground)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : foreground))),
    navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: foreground),
        selectedLabelTextStyle:
            TextStyle(color: foreground, fontWeight: FontWeight.bold),
        unselectedLabelTextStyle: TextStyle(color: foreground)),
    snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF202020),
        contentTextStyle: TextStyle(color: Colors.white),
        actionTextColor: Colors.white),
    switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(foreground),
        trackOutlineWidth: const WidgetStatePropertyAll(2),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : Colors.white),
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : foreground)),
    checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: foreground, width: 2),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : Colors.white),
        checkColor: const WidgetStatePropertyAll(Colors.white)),
    chipTheme: base.chipTheme.copyWith(
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: TextStyle(
            color: WidgetStateColor.resolveWith((s) =>
                s.contains(WidgetState.selected)
                    ? scheme.onPrimaryContainer
                    : foreground)),
        secondaryLabelStyle: TextStyle(color: scheme.onPrimaryContainer),
        checkmarkColor: scheme.onPrimaryContainer),
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
            excludeFromSemantics: true,
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

String formatMoney(int cents) {
  final amount = (cents.abs() ~/ 100).toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
  return '${cents < 0 ? '-' : ''}R\$ $amount,${(cents.abs() % 100).toString().padLeft(2, '0')}';
}

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
