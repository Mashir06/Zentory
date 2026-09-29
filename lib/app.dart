import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart';
import 'screens/ayuda_screen.dart';
import 'screens/calendario_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/registrar_producto_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/session_gate.dart';
import 'screens/settings_screen.dart';
import 'screens/store_selection_screen.dart';
import 'theme/app_theme.dart';

class ZentoryApp extends StatelessWidget {
  const ZentoryApp({super.key});

  static Widget _page(String? name, Object? args) {
    switch (name) {
      case Routes.login:
        return const LoginScreen();
      case Routes.register:
        return const RegistroScreen();
      case Routes.storeSelection:
        return const StoreSelectionScreen();
      case Routes.onboarding:
        return const OnboardingScreen();
      case Routes.home:
        return const HomeScreen();
      case Routes.calendar:
        return const CalendarioScreen();
      case Routes.scan:
        return const QRScreen();
      case Routes.productos:
        return const ProductosScreen();
      case Routes.profile:
        return const ProfileScreen();
      case Routes.settings:
        return const SettingsScreen();
      case Routes.help:
        return const AyudaScreen();
      case Routes.faq:
        return const FaqScreen();
      case Routes.privacySettings:
        return const PrivacySettingsScreen();
      case Routes.addProduct:
        return RegistrarProductoScreen(
          args: args is AddProductArgs ? args : const AddProductArgs(),
        );
      case Routes.session:
      default:
        return const SessionGate();
    }
  }

  static Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final page = _page(settings.name, settings.arguments);
    // Las pestañas de la barra inferior cambian sin animación.
    if (Routes.tabs.contains(settings.name)) {
      return PageRouteBuilder<void>(
        settings: settings,
        pageBuilder: (_, _, _) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }
    return MaterialPageRoute<void>(settings: settings, builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zentory',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [routeObserver],
      initialRoute: Routes.session,
      onGenerateRoute: _onGenerateRoute,
    );
  }
}
