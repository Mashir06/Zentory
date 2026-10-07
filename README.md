# Zentory

App móvil para el **control de caducidad e inventario de minisúpers**, ahora escrita en **Flutter** (antes Kotlin + Jetpack Compose).

Permite registrar productos con su fecha de vencimiento, recibir alertas antes de que venzan, escanear códigos de barras para autocompletar la información y compartir el inventario con el personal de la tienda mediante un código de invitación.

## Funciones

- **Inicio de sesión** con correo y contraseña, registro y recuperación de contraseña (Firebase Auth). Las cuentas nuevas ven "Espere la confirmación de Zentory" hasta que NubikSoft las aprueba en el panel web (`usuarios/{uid}.aprobado` y `estadoAcceso`: pendiente, aprobado, rechazado o bloqueado). Una cuenta rechazada puede volver a pedir acceso; una bloqueada no. Si se bloquea a alguien mientras usa la app, la app se cierra al instante. Las cuentas antiguas no se ven afectadas.
- **Tiendas**: crear una tienda, unirse con código de invitación, sucursales, cambiar de tienda activa y administrar al personal. Solo el administrador puede eliminar la tienda o sus sucursales; los trabajadores no.
- **Inicio**: resumen de lotes en buen estado, por vencer (7 días) y vencidos, alerta de los que vencen mañana y gráfica por estado.
- **Productos**: cada producto con sus lotes (los lotes se borran solos 3 días después de vencer); búsqueda, filtro por estado, ordenamiento, agregar/editar/eliminar lotes y editar/eliminar productos.
- **Registrar producto**: nombre, foto (cámara o galería) y presentación. **Agregar lote**: fecha de vencimiento y cantidad.
- **Escáner** de códigos de barras dentro de "Agregar producto" (el código es obligatorio). El código identifica a cada producto, así que puede haber varios con el mismo nombre (p. ej. Coca-Cola de 600 ml y de 2 L). Al escanear un código que ya está registrado, la app abre directo el formulario de un nuevo lote de ese producto.
- **Calendario** mensual con indicadores de vencimiento por día.
- **Notificaciones** locales 3 días y 1 día antes del vencimiento (7:00 a. m.), con sonido propio.
- **Suscripción y pagos** (Ajustes > Estado del pago): solo información (estado, mensualidad de $25 o `suscripcion.monto`, próxima fecha de pago, aviso y días de gracia, si se pueden editar productos, último pago e historial para el administrador de la tienda). Por la política de pagos de Google Play, la app no tiene ningún botón, enlace ni texto para pagar fuera de Google Play: NubikSoft envía el enlace de pago por WhatsApp desde el panel. El único contacto es el WhatsApp de soporte (+507 6796-8449).
- Ajustes: modo oscuro (predeterminado) o claro, e idioma (español, inglés o chino mandarín). También privacidad, preguntas frecuentes y contacto de soporte (WhatsApp de soporte técnico).


## Versión web (iPhone y computadoras)

- Misma app Flutter compilada para la web (`flutter build web --base-href /zentory/app/`). GitHub Actions genera `zentory-web.zip` en cada versión: su carpeta `zentory/app/` se copia dentro del sitio y queda en https://nubiksoft.com/zentory/app/.
- En iPhone se abre en Safari y se instala con Compartir → "Agregar a pantalla de inicio" (la pantalla de inicio de sesión lo explica).
- Funciona igual: cuentas, aprobación, tiendas, productos, lotes, escáner con la cámara, fotos, calendario, idiomas y suscripción. Usa el mismo Firebase (app web `1:794054120945:web:…`).
- **Sin alertas automáticas**: el navegador no puede programar notificaciones locales. `lib/services/notification_service.dart` elige `notification_service_io.dart` (Android) o `notification_service_web.dart` (no hace nada). Para alertas en la web haría falta envío desde un servidor (Firebase Cloud Messaging + Cloud Functions, plan Blaze).
- En la web no aparecen la guía de notificaciones, la prueba de alertas ni la linterna del escáner.

## Requisitos

- Flutter estable (probado para Flutter 3.47 / Dart 3.11 o superior)
- Android SDK (la app requiere Android 10 / API 29 o superior)

## Cómo ejecutarla

```bash
flutter pub get
flutter run
```

Para generar un APK:

```bash
flutter build apk --release
```

> La primera vez, Flutter crea `android/local.properties` y el wrapper de Gradle automáticamente.

## Firebase

La app usa el mismo proyecto de Firebase que la versión Kotlin (`zentory-base`) y conserva el paquete `com.example.zentoryapp`, así que los usuarios y datos existentes siguen funcionando.

- Android: `android/app/google-services.json` y `lib/firebase_options.dart`.
- Para agregar iOS o web: `dart pub global activate flutterfire_cli` y luego `flutterfire configure`.

### Estructura de datos en Firestore

```
usuarios/{uid}                    nombre, correo, uid, tiendaId, tiendasIds
tiendas/{nombreTienda}            nombre, ubicacion, adminUid, adminNombre, codigoInvitacion
  personal/{nombreUsuario}        uid, nombre, correo, rol, fechaUnion
  catalogo/{nombreProducto}       PRODUCTO: nombre, presentacion, imagen (Base64)
  productos/{id}                  LOTE: nombre, presentacion, imagen, cantidad,
                                  fechaVencimiento (d/M/yyyy), fechaRegistro, usuarioId
  minisupers/{id}                 sucursales
```

- **Producto**: se registra con nombre, foto y presentación (tamaño).
- **Lote**: cada ingreso de un producto, con su fecha de vencimiento y cantidad. Los lotes de un mismo producto se agrupan por nombre.

## Estructura del proyecto

```
lib/
  main.dart                  Inicializa Firebase, fechas en español y notificaciones
  app.dart                   MaterialApp, tema y rutas
  routes.dart                Nombres de rutas y navegación entre pestañas
  firebase_options.dart      Configuración de Firebase
  models/                    Producto, lote y agrupación de lotes
  services/                  Firestore, autenticación, notificaciones y OpenFoodFacts
  screens/                   Una pantalla por archivo
  widgets/                   Componentes reutilizables (tarjetas, diálogos, gráfica…)
  theme/                     Colores y tema oscuro
  utils/                     Fechas e imágenes
assets/                      Logo y fuente Inter
android/                     Proyecto Android del runner de Flutter
test/                        Pruebas unitarias
```

## Notificaciones en teléfonos con ROM china

Las alertas de vencimiento son notificaciones locales programadas (3 días antes, 1 día antes y el día del vencimiento, a las 7:00 a. m.). Sistemas como **ColorOS (OPPO/realme/OnePlus), MIUI/HyperOS (Xiaomi), OriginOS (vivo) o EMUI/HarmonyOS (Huawei/Honor)**, sobre todo en sus versiones para China, cierran las apps en segundo plano y borran sus alarmas. Para que las alertas lleguen igual:

- La app **reprograma todas las alertas** de la tienda cada vez que se abre, se vuelve al Inicio o se guarda o elimina un producto.
- Cada lote tiene sus propias alertas (identificadas por el ID del registro).
- En **Ajustes → Configurar notificaciones** hay una guía que revisa y abre directamente: permiso de notificaciones, alarmas exactas, restricción de batería e inicio automático/segundo plano del fabricante, además de una **prueba programada a 1 minuto** para comprobarlo con la app cerrada.
- La guía se abre sola una vez en los teléfonos de esos fabricantes.

En OPPO (ColorOS): Ajustes → Apps → Gestión de apps → Zentory → Uso de batería → activar **Permitir actividad en segundo plano** y **Permitir inicio automático**; y fijar Zentory en Recientes con el candado.

## Pruebas

```bash
flutter analyze
flutter test
```

## Versión anterior (Kotlin)

El código original en Kotlin/Compose se retiró del repositorio al completar la migración. Sigue disponible en el historial de Git, en el commit `41a230a` (carpeta `APP/`).
