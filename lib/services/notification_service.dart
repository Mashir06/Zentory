// Alertas de vencimiento.
//
// En Android (y demás plataformas nativas) se programan notificaciones
// locales. En la versión web no hay alertas locales programadas: se usa una
// versión que no hace nada, para que la web no cargue el plugin nativo.
export 'notification_service_io.dart'
    if (dart.library.js_interop) 'notification_service_web.dart';
