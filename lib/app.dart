import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes.dart';
import 'screens/ayuda_screen.dart';
import 'screens/calendario_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pending_approval_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_screen.dart';
import 'screens/registrar_producto_screen.dart';
import 'screens/registro_screen.dart';
import 'screens/session_gate.dart';
import 'screens/settings_screen.dart';
import 'screens/store_selection_screen.dart';
import 'screens/subscription_screen.dart';
import 'l10n/strings.dart';
import 'services/access_guard.dart';
import 'services/app_settings.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class ZentoryApp extends StatefulWidget {
  const ZentoryApp({super.key});

  @override
  State<ZentoryApp> createState() => _ZentoryAppState();

  static Widget _page(String? name, Object? args) {
    switch (name) {
      case Routes.login:
        return LoginScreen();
      case Routes.register:
        return RegistroScreen();
      case Routes.pendingApproval:
        return PendingApprovalScreen();
      case Routes.storeSelection:
        return StoreSelectionScreen();
      case Routes.onboarding:
        return OnboardingScreen();
      case Routes.home:
        return HomeScreen();
      case Routes.calendar:
        return CalendarioScreen();
      case Routes.scan:
        return QRScreen();
      case Routes.productos:
        return ProductosScreen();
      case Routes.profile:
        return ProfileScreen();
      case Routes.settings:
        return SettingsScreen();
      case Routes.subscription:
        return SubscriptionScreen();
      case Routes.help:
        return AyudaScreen();
      case Routes.faq:
        return FaqScreen();
      case Routes.privacySettings:
        return PrivacySettingsScreen();
      case Routes.addProduct:
        return ProductFormScreen(
          args: args is ProductFormArgs ? args : ProductFormArgs(),
        );
      case Routes.lotForm:
        return LotFormScreen(
          args: args is LotFormArgs ? args : LotFormArgs(nombre: ''),
        );
      case Routes.session:
      default:
        return SessionGate();
    }
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
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

}

class _ZentoryAppState extends State<ZentoryApp> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.revision.addListener(_onSettingsChanged);
    AccessGuard.instance.start();
  }

  @override
  void dispose() {
    AppSettings.instance.revision.removeListener(_onSettingsChanged);
    super.dispose();
  }

  /// Modo oscuro/claro o idioma cambiados: se vuelven a dibujar todas las
  /// pantallas abiertas (los colores y textos se leen al dibujar), sin perder
  /// la navegación ni lo que el usuario estaba escribiendo.
  void _onSettingsChanged() {
    setState(() {});
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.current;
    return MaterialApp(
      title: 'Zentory',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: AppColors.isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(currentLanguage.code),
      supportedLocales: [for (final l in AppLanguage.values) Locale(l.code)],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: AccessGuard.instance.navigatorKey,
      navigatorObservers: [routeObserver, AccessGuard.instance],
      initialRoute: Routes.session,
      onGenerateRoute: ZentoryApp.onGenerateRoute,
      // Íconos de la barra de estado claros u oscuros según el modo.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: kIsWeb
            ? _WideScreenFrame(child: child ?? SizedBox.shrink())
            : child ?? SizedBox.shrink(),
      ),
    );
  }
}

/// En la web, en pantallas anchas (computadora, tablet horizontal) la app se
/// muestra centrada con ancho de teléfono, en vez de estirarse a todo lo
/// ancho. En el celular no cambia nada.
class _WideScreenFrame extends StatelessWidget {
  const _WideScreenFrame({required this.child});

  final Widget child;

  static const _maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= _maxWidth + 120) return child;
    return ColoredBox(
      color: AppColors.backgroundBottom,
      child: Center(
        child: Container(
          width: _maxWidth,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.border, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 40,
              ),
            ],
          ),
          child: MediaQuery(
            data: mq.copyWith(size: Size(_maxWidth, mq.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
