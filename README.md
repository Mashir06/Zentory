# Zentory

App móvil para el **control de caducidad e inventario de minisúpers**, ahora escrita en **Flutter** (antes Kotlin + Jetpack Compose).

Permite registrar productos con su fecha de vencimiento, recibir alertas antes de que venzan, escanear códigos de barras para autocompletar la información y compartir el inventario con el personal de la tienda mediante un código de invitación.

## Funciones

- **Inicio de sesión** con correo/contraseña o Google, registro y recuperación de contraseña (Firebase Auth).
- **Tiendas**: crear una tienda, unirse con código de invitación, sucursales, cambiar de tienda activa y administrar al personal. Solo el administrador puede eliminar la tienda o sus sucursales; los trabajadores no.
- **Inicio**: resumen de lotes en buen estado, por vencer (7 días) y vencidos, alerta de los que vencen mañana y gráfica por estado.
- **Productos**: cada producto con sus lotes; búsqueda, filtro por estado, ordenamiento, agregar/editar/eliminar lotes y editar/eliminar productos.
- **Registrar producto**: nombre, foto (cámara o galería) y presentación. **Agregar lote**: fecha de vencimiento y cantidad.
- **Escáner** de códigos de barras con consulta a [OpenFoodFacts](https://world.openfoodfacts.org) y linterna.
- **Calendario** mensual con indicadores de vencimiento por día.
- **Notificaciones** locales 3 días y 1 día antes del vencimiento (9:00 a. m.), con sonido propio.
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

## Notificaciones en teléfonos con ROM china

Las alertas de vencimiento son notificaciones locales programadas (3 días antes, 1 día antes y el día del vencimiento, a las 9:00 a. m.). Sistemas como **ColorOS (OPPO/realme/OnePlus), MIUI/HyperOS (Xiaomi), OriginOS (vivo) o EMUI/HarmonyOS (Huawei/Honor)**, sobre todo en sus versiones para China, cierran las apps en segundo plano y borran sus alarmas. Para que las alertas lleguen igual:

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
