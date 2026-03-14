import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'router/app_router.dart';

class ShiTiApp extends StatelessWidget {
  const ShiTiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const telegramBlue = Color(0xFF3390EC);
    const telegramBlueDark = Color(0xFF2B79C2);
    const shellBackground = Color(0xFFE9EFF5);
    const shellForeground = Color(0xFF1F2D3D);
    const mutedForeground = Color(0xFF5B7083);
    const cardBorder = Color(0xFFD7E3EE);

    return MaterialApp(
      title: 'ShiTi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: telegramBlue,
          brightness: Brightness.light,
        ).copyWith(
          primary: telegramBlue,
          secondary: const Color(0xFF64B5F6),
          surface: Colors.white,
          onSurface: shellForeground,
        ),
        scaffoldBackgroundColor: shellBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: shellForeground,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: shellForeground,
          displayColor: shellForeground,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: cardBorder),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: telegramBlue.withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? telegramBlueDark
                  : mutedForeground,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? telegramBlueDark
                  : mutedForeground,
            );
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF2F7FC),
          selectedColor: telegramBlue.withValues(alpha: 0.12),
          side: const BorderSide(color: cardBorder),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          labelStyle: const TextStyle(
            color: shellForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: telegramBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFDDE9F5),
            disabledForegroundColor: mutedForeground,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: telegramBlueDark,
            side: const BorderSide(color: cardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: telegramBlueDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F8FB),
          hintStyle: const TextStyle(color: mutedForeground),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: telegramBlue, width: 1.4),
          ),
        ),
        dividerColor: cardBorder,
        useMaterial3: true,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
      builder: (context, child) {
        return Banner(
          message: '${AppConfig.environmentLabel} ${AppConfig.dataModeLabel}',
          location: BannerLocation.topEnd,
          color: telegramBlueDark,
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
