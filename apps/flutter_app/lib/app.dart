import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/services/app_services.dart';
import 'core/theme/telegram_palette.dart';
import 'router/app_router.dart';

class ShiTiApp extends StatelessWidget {
  const ShiTiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const webFontFamily = 'ShiTiSans';
    const webFontFallback = <String>[
      'PingFang SC',
      'Hiragino Sans GB',
      'Microsoft YaHei',
      'Noto Sans SC',
      'Noto Sans CJK SC',
      'Source Han Sans SC',
      'WenQuanYi Micro Hei',
      'Arial Unicode MS',
      'Arial',
      'sans-serif',
    ];
    final appFontFamily = kIsWeb ? webFontFamily : null;
    final appFontFallback = kIsWeb ? webFontFallback : null;
    return MaterialApp(
      title: 'ShiTi',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppServices.instance.navigatorKey,
      theme: ThemeData(
        fontFamily: appFontFamily,
        fontFamilyFallback: appFontFallback,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TelegramPalette.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: TelegramPalette.accent,
          secondary: const Color(0xFF64B5F6),
          surface: TelegramPalette.surfaceRaised,
          onSurface: TelegramPalette.text,
        ),
        scaffoldBackgroundColor: TelegramPalette.shell,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: TelegramPalette.text,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: ThemeData.light().textTheme.apply(
              fontFamily: appFontFamily,
              fontFamilyFallback: appFontFallback,
              bodyColor: TelegramPalette.text,
              displayColor: TelegramPalette.text,
            ),
        cardTheme: const CardThemeData(
          color: TelegramPalette.surfaceRaised,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            side: BorderSide(color: TelegramPalette.border),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.92),
          indicatorColor: TelegramPalette.accent.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? TelegramPalette.accentDark
                  : TelegramPalette.textMuted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? TelegramPalette.accentDark
                  : TelegramPalette.textMuted,
            );
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: TelegramPalette.surface,
          selectedColor: TelegramPalette.accent.withValues(alpha: 0.12),
          side: const BorderSide(color: TelegramPalette.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          labelStyle: const TextStyle(
            color: TelegramPalette.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const Color(0xFFE5EEF7);
              }
              return TelegramPalette.accent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return TelegramPalette.textStrong;
              }
              return Colors.white;
            }),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return TelegramPalette.surfaceSoft;
              }
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return TelegramPalette.textSoft;
              }
              return TelegramPalette.accentDark;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return const BorderSide(color: TelegramPalette.borderAccent);
              }
              return const BorderSide(color: TelegramPalette.border);
            }),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return TelegramPalette.textSoft;
              }
              return TelegramPalette.accentDark;
            }),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F8FB),
          hintStyle: const TextStyle(color: TelegramPalette.textMuted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: TelegramPalette.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: TelegramPalette.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: TelegramPalette.accent, width: 1.4),
          ),
        ),
        dividerColor: TelegramPalette.border,
        useMaterial3: true,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
      builder: (context, child) {
        return Banner(
          message: '${AppConfig.environmentLabel} ${AppConfig.dataModeLabel}',
          location: BannerLocation.topEnd,
          color: TelegramPalette.accentDark,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.6,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
