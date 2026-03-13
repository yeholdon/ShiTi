import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'router/app_router.dart';

class ShiTiApp extends StatelessWidget {
  const ShiTiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ShiTi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F6F2),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF3F6F2),
          foregroundColor: Color(0xFF163A36),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        useMaterial3: true,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
      builder: (context, child) {
        return Banner(
          message: '${AppConfig.environmentLabel} ${AppConfig.dataModeLabel}',
          location: BannerLocation.topEnd,
          color: const Color(0xFF0F766E),
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
