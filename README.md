# Zentory

App móvil para el **control de caducidad e inventario de minisúpers**, ahora escrita en **Flutter** (antes Kotlin + Jetpack Compose).

Permite registrar productos con su fecha de vencimiento, recibir alertas antes de que venzan, escanear códigos de barras para autocompletar la información y compartir el inventario con el personal de la tienda mediante un código de invitación.

## Funciones

- **Inicio de sesión** con correo/contraseña o Google, registro y recuperación de contraseña (Firebase Auth).
- **Tiendas**: crear una tienda, unirse con código de invitación, sucursales, cambiar de tienda activa y administrar al personal.
- **Inicio**: resumen de lotes en buen estado, por vencer (7 días) y vencidos, alerta de los que vencen mañana y gráfica por estado.
- **Productos**: cada producto con sus lotes; búsqueda, filtro por estado, ordenamiento, agregar/editar/eliminar lotes y editar/eliminar productos.
- **Registrar producto**: nombre, foto (cámara o galería) y presentación. **Agregar lote**: fecha de vencimiento y cantidad.
- **Escáner** de códigos de barras con consulta a [OpenFoodFacts](https://world.openfoodfacts.org) y linterna.
- **Calendario** mensual con indicadores de vencimiento por día.
- **Notificaciones** de vencimiento por push (FCM) a todo el personal de la tienda, con alarmas locales de respaldo.
- Ajustes, privacidad, ayuda por WhatsApp, manual de usuario y preguntas frecuentes.

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
- **Inicio de sesión con Google**: la huella SHA-1 de la llave con la que firmes la app debe estar registrada en la consola de Firebase (Configuración del proyecto → Tus apps → Android). Obtén la de depuración con `cd android && ./gradlew signingReport`.
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
  utils/                     Fechas, imágenes y manual de usuario
assets/                      Logo, fuente Inter y manual.docx
android/                     Proyecto Android del runner de Flutter
test/                        Pruebas unitarias
```

## Notificaciones de vencimiento

Hay dos canales y la app elige sola:

1. **Push (Firebase Cloud Messaging)**, el principal. Una Cloud Function (`functions/index.js`) revisa cada día a las 9:00 (hora de Panamá) los lotes de cada tienda y avisa **a todos los teléfonos registrados en la tienda**: 3 días antes, 1 día antes y el día del vencimiento.
2. **Alarmas locales del teléfono**, el respaldo. Se usan solo si el push no cubre ese teléfono (sin servicios de Google o con el servidor sin activar). Cuando el push funciona, se apagan para no duplicar avisos.

Cada teléfono se registra en `tiendas/{tiendaId}/dispositivos/{token}` al abrir la app. El servidor guarda `tiendas/{id}.pushServidor.ultimaEjecucion` en cada revisión; la app lo usa para saber si el push está activo.

En **Ajustes → Configurar notificaciones** se ve el estado del push (servicios de Google, registro del teléfono, servidor), con botones para activar los servicios de Google y **probar un push**, además de los permisos, la batería, el inicio automático y la prueba de alarma local.

### Activar el servidor de avisos (una sola vez)

1. **Plan Blaze:** en la consola de Firebase del proyecto `zentory-base` → Uso y facturación → cambia al plan **Blaze** (pago por uso; con pocas tiendas el costo es prácticamente nulo, pero pide una tarjeta).
2. **Desplegar las funciones**, con una de estas opciones:
   - **Desde tu computadora:** instala Node 22 y ejecuta
     ```bash
     npm install -g firebase-tools
     firebase login
     cd functions && npm install && cd ..
     firebase deploy --only functions
     ```
   - **Automático desde GitHub:** en Google Cloud Console → IAM → Cuentas de servicio, crea una cuenta con los roles *Administrador de Firebase*, *Administrador de Cloud Functions*, *Usuario de cuenta de servicio*, *Administrador de Cloud Scheduler* y *Consumidor de uso de servicios*; descarga su clave JSON y guárdala en GitHub como secreto `FIREBASE_SERVICE_ACCOUNT`. Después, en Actions → "Desplegar Cloud Functions" → **Run workflow**. Cada cambio en `functions/` se desplegará solo.
3. **Reglas de Firestore:** los usuarios con sesión deben poder escribir en `tiendas/{tiendaId}/dispositivos/{token}` y `tiendas/{tiendaId}/pruebasPush/{id}`.

### Teléfonos con ROM china

- **OPPO / OnePlus / realme / Xiaomi de versión china:** suelen traer los servicios de Google **desactivados**; actívalos (la guía de la app tiene un botón). En OPPO también está en Ajustes → Cuentas → Servicios básicos de Google.
- **Huawei (desde 2019) y algunos vivo:** no tienen servicios de Google; usan las alarmas locales.
- **Cerrar la app desde Recientes** hace que algunos sistemas la detengan a la fuerza; en ese estado Android bloquea **tanto las alarmas como el push**. Fija Zentory con el candado en Recientes. La app detecta cuando esto pasó y lo avisa en la guía.

## Pruebas

```bash
flutter analyze
flutter test
cd functions && npm install && npm test   # Cloud Functions
```

## Versión anterior (Kotlin)

El código original en Kotlin/Compose se retiró del repositorio al completar la migración. Sigue disponible en el historial de Git, en el commit `41a230a` (carpeta `APP/`).
