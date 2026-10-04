// Textos de la app en inglés y chino (mandarín, simplificado).
//
// La clave es el texto original en español: `tr('Agregar lote')`. Los valores
// variables se escriben como {0}, {1}... y se pasan en una lista:
// `tr('Lote {0}', [label])`. Si un texto no está en el diccionario se muestra
// tal cual (en español).

/// Idiomas disponibles.
enum AppLanguage {
  es('Español', 'es'),
  en('English', 'en'),
  zh('中文（普通话）', 'zh');

  const AppLanguage(this.label, this.code);

  /// Nombre del idioma escrito en ese mismo idioma.
  final String label;
  final String code;
}

/// Idioma actual. Lo cambia `AppSettings`.
AppLanguage currentLanguage = AppLanguage.es;

/// Traduce [key] (texto en español) al idioma actual.
String tr(String key, [List<Object?> args = const []]) {
  var text = switch (currentLanguage) {
    AppLanguage.es => key,
    AppLanguage.en => _en[key] ?? key,
    AppLanguage.zh => _zh[key] ?? key,
  };
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return text;
}

const Map<String, String> _en = {
  'Hola, quiero consultar o pagar la suscripción de Zentory de la tienda {0}.':
      'Hi, I\'d like to check or pay the Zentory subscription for the store {0}.',
  'Suscripción y pagos':
      'Subscription and payments',
  'No se pudo cargar la suscripción. Revisa tu conexión a internet.':
      'Couldn\'t load the subscription. Check your internet connection.',
  'No perteneces a ninguna tienda.':
      'You don\'t belong to any store.',
  'Plan mensual de Zentory':
      'Zentory monthly plan',
  'Próximo pago':
      'Next payment',
  'Aviso de pago desde':
      'Payment reminder from',
  'Último día de gracia':
      'Last grace day',
  'Después, la tienda queda en solo lectura':
      'After that, the store becomes read-only',
  'Agregar y editar productos':
      'Add and edit products',
  'Permitido':
      'Allowed',
  'Bloqueado':
      'Blocked',
  'Último pago':
      'Last payment',
  'Registrado el {0}':
      'Recorded on {0}',
  'Contactar a Zentory por WhatsApp':
      'Contact Zentory on WhatsApp',
  'Pagar o consultar por WhatsApp':
      'Pay or ask on WhatsApp',
  'Cómo funciona el pago':
      'How payment works',
  'Se paga una mensualidad por tienda, al final de cada mes de uso. No hay pago inicial.':
      'Each store pays a monthly fee at the end of each month of use. There\'s no upfront payment.',
  'La app te avisa {0} días antes de la fecha de pago.':
      'The app reminds you {0} days before the payment date.',
  'Si la fecha pasa, tienes {0} días de gracia para pagar sin perder nada.':
      'If the date passes, you have {0} grace days to pay without losing anything.',
  'Después, la tienda queda en solo lectura: puedes ver tu inventario, pero no agregar ni editar productos.':
      'After that, the store becomes read-only: you can see your inventory, but not add or edit products.',
  'Tus datos nunca se borran. Al registrar el pago, la tienda se reactiva al instante.':
      'Your data is never deleted. Once the payment is recorded, the store is reactivated right away.',
  'Historial de pagos':
      'Payment history',
  'No se pudo cargar el historial.':
      'Couldn\'t load the history.',
  'Todavía no hay pagos registrados.':
      'No payments recorded yet.',
  'El historial de pagos solo lo ve el administrador de la tienda.':
      'Only the store administrator can see the payment history.',
  'Sin pago':
      'No charge',
  'Zentory le dio a esta tienda uso sin pago. No tiene cobros ni vencimientos.':
      'Zentory gave this store free use. It has no charges or due dates.',
  'Activa':
      'Active',
  'Tu tienda todavía no tiene fechas de pago registradas.':
      'Your store doesn\'t have any payment dates recorded yet.',
  'Al día':
      'Up to date',
  'Todo en orden. Faltan {0} días para el próximo pago.':
      'All good. {0} days until the next payment.',
  'El pago vence hoy.':
      'Payment is due today.',
  'El pago vence en {0} días.':
      'Payment is due in {0} days.',
  'Vencida (en gracia)':
      'Overdue (grace period)',
  'El pago venció. La tienda sigue funcionando hasta el {0}.':
      'The payment is overdue. The store keeps working until {0}.',
  'Suspendida':
      'Suspended',
  'Puedes ver tu inventario, pero no agregar ni editar productos hasta pagar.':
      'You can see your inventory, but you can\'t add or edit products until you pay.',
  'Hoy':
      'Today',
  'Mañana':
      'Tomorrow',
  'En {0} días':
      'In {0} days',
  '1 mes':
      '1 month',
  '{0} meses':
      '{0} months',
  'cubre hasta el {0}':
      'covers until {0}',
  'Solicitud enviada':
      'Request sent',
  'No se pudo enviar la solicitud. Revisa tu conexión.':
      'Couldn\'t send the request. Check your connection.',
  'Tu solicitud fue rechazada':
      'Your request was rejected',
  'El equipo de Zentory no aprobó tu cuenta. Si crees que es un error, contáctanos o vuelve a enviar la solicitud.':
      'The Zentory team didn\'t approve your account. If you think this is a mistake, contact us or send the request again.',
  'Solicitud rechazada':
      'Request rejected',
  'Tu cuenta está bloqueada':
      'Your account is blocked',
  'No puedes usar Zentory con esta cuenta. Contacta a Zentory para más información.':
      'You can\'t use Zentory with this account. Contact Zentory for more information.',
  'Cuenta bloqueada':
      'Account blocked',
  'Volver a solicitar acceso':
      'Request access again',
  'Suscripción':
      'Subscription',
  'Estado del pago':
      'Payment status',
  'Próximo pago, días de gracia e historial':
      'Next payment, grace days and history',
  'Espere la confirmación de Zentory':
      'Wait for Zentory\'s confirmation',
  'Tu cuenta fue creada. El equipo de Zentory debe aprobarla antes de que puedas usar la app. Esta pantalla se quitará sola en cuanto te den acceso.':
      'Your account was created. The Zentory team must approve it before you can use the app. This screen will go away on its own as soon as you\'re given access.',
  'Esperando aprobación':
      'Waiting for approval',
  'Contactar a Zentory':
      'Contact Zentory',
  'Hola, soy {0} de la tienda {1}. {2}':
      'Hi, I\'m {0} from the store {1}. {2}',
  'No se pudo abrir WhatsApp':
      'Couldn\'t open WhatsApp',
  'No se pudo abrir la página de Zentory':
      'Couldn\'t open the Zentory page',
  'Ayuda y Soporte':
      'Help & Support',
  '¿En qué podemos ayudarte?':
      'How can we help you?',
  'Preguntas Frecuentes (FAQ)':
      'Frequently Asked Questions (FAQ)',
  'Contactar Soporte':
      'Contact Support',
  'Soporte Técnico':
      'Technical Support',
  'Necesito soporte técnico.':
      'I need technical support.',
  'Consultas Generales':
      'General Inquiries',
  'Tengo una consulta general.':
      'I have a general question.',
  'No se pudieron cargar los productos: {0}':
      'Couldn\'t load the products: {0}',
  'Todos los lotes':
      'All batches',
  'Lotes que vencen el {0}':
      'Batches expiring on {0}',
  'Lotes de {0}':
      'Batches in {0}',
  '{0} lote':
      '{0} batch',
  '{0} lotes':
      '{0} batches',
  ' de {0} producto':
      ' of {0} product',
  ' de {0} productos':
      ' of {0} products',
  '1 lote vence hoy':
      '1 batch expires today',
  '{0} lotes vencen hoy':
      '{0} batches expire today',
  'Revisa tu inventario y evita pérdidas':
      'Check your inventory and avoid losses',
  'Ver todos':
      'View all',
  'No hay lotes que venzan en esta fecha':
      'No batches expire on this date',
  'Mes anterior':
      'Previous month',
  'Mes siguiente':
      'Next month',
  'Sin nombre':
      'No name',
  '{0} un.':
      '{0} units',
  '¿Cómo agrego un nuevo producto?':
      'How do I add a new product?',
  '¿Cómo invito a alguien a mi tienda?':
      'How do I invite someone to my store?',
  'En tu perfil, encontrarás el \'Código de Invitación\' de tu tienda. Compártelo con tus empleados para que puedan unirse desde su propia cuenta.':
      'In your profile you\'ll find your store\'s \'Invitation Code\'. Share it with your employees so they can join from their own account.',
  '¿Puedo tener varias tiendas?':
      'Can I have several stores?',
  'Sí, puedes crear múltiples tiendas o sucursales desde tu perfil y alternar entre ellas en cualquier momento.':
      'Yes, you can create multiple stores or branches from your profile and switch between them at any time.',
  '¿Cómo cambio mi contraseña?':
      'How do I change my password?',
  'Preguntas Frecuentes':
      'Frequently Asked Questions',
  'No se pudieron cargar los datos: {0}':
      'Couldn\'t load the data: {0}',
  'Debes unirte a una tienda antes de poder agregar un producto':
      'You must join a store before you can add a product',
  'Configuración':
      'Settings',
  '¡Hola, {0}! 👋':
      'Hi, {0}! 👋',
  'Aquí tienes el resumen de tu minisúper':
      'Here\'s your store summary',
  'Agregar producto':
      'Add product',
  'En buen estado':
      'In good condition',
  'Por vencer (7 días)':
      'Expiring soon (7 days)',
  'Vencidos':
      'Expired',
  'Total de productos':
      'Total products',
  '{0} productos vencen mañana':
      '{0} products expire tomorrow',
  'Inventario por estado':
      'Inventory by status',
  '¡Aún no tienes una tienda!':
      'You don\'t have a store yet!',
  'Para empezar a gestionar tus productos, necesitas unirte a una tienda o crear la tuya desde tu perfil.':
      'To start managing your products, join a store or create your own from your profile.',
  'Configurar Tienda':
      'Set up store',
  'Productos':
      'Products',
  'Por favor llena todos los campos':
      'Please fill in all the fields',
  '¡Bienvenido!':
      'Welcome!',
  'Por favor, ingresa tu correo primero':
      'Please enter your email first',
  'Se ha enviado un correo para restablecer tu contraseña':
      'An email to reset your password has been sent',
  'Error al enviar correo: {0}':
      'Error sending email: {0}',
  'Logo de Zentory':
      'Zentory logo',
  '¡Bienvenido de nuevo!':
      'Welcome back!',
  'Iniciar sesión para continuar':
      'Sign in to continue',
  'Correo electrónico':
      'Email',
  'Ingresa tu correo electrónico':
      'Enter your email',
  'Contraseña':
      'Password',
  'Ingresa tu contraseña':
      'Enter your password',
  'Ocultar contraseña':
      'Hide password',
  'Mostrar contraseña':
      'Show password',
  '¿Olvidaste tu contraseña?':
      'Forgot your password?',
  'Iniciar sesión':
      'Sign in',
  '¿No tienes una cuenta? ':
      'Don\'t have an account? ',
  'Regístrate aquí':
      'Sign up here',
  'No se pudo obtener el correo del usuario':
      'Couldn\'t get the user\'s email',
  'Se ha enviado un correo para restablecer tu contraseña a {0}':
      'An email to reset your password has been sent to {0}',
  'Privacidad y Seguridad':
      'Privacy & Security',
  'Seguridad de la cuenta':
      'Account security',
  'Cambiar Contraseña':
      'Change password',
  'Recibirás un correo para restablecerla':
      'You\'ll receive an email to reset it',
  'Estado de la cuenta':
      'Account status',
  'Tu cuenta está protegida por Zentory':
      'Your account is protected by Zentory',
  'Datos personales':
      'Personal data',
  'Eliminar mi cuenta':
      'Delete my account',
  'Opción no disponible en esta versión':
      'Option not available in this version',
  'Eliminar lote':
      'Delete batch',
  '¿Deseas eliminar el lote {0} de "{1}" (vence {2})?':
      'Delete batch {0} of "{1}" (expires {2})?',
  '¿Deseas eliminar "{0}" del inventario?':
      'Delete "{0}" from the inventory?',
  'Eliminado':
      'Deleted',
  'No se pudo eliminar: {0}':
      'Couldn\'t delete: {0}',
  'Filtros':
      'Filters',
  'Limpiar':
      'Clear',
  'Estado':
      'Status',
  'Ver resultados':
      'Show results',
  'Gestiona tus productos, consulta sus lotes y mantén el control de tu inventario.':
      'Manage your products, check their batches and keep your inventory under control.',
  'Buscar producto...':
      'Search product...',
  'Borrar búsqueda':
      'Clear search',
  'Ordenar':
      'Sort',
  'Limpiar filtros':
      'Clear filters',
  'Inventario vacío.':
      'Inventory is empty.',
  'Sin coincidencias.':
      'No matches.',
  'Total: ':
      'Total: ',
  'Lotes ({0})':
      'Batches ({0})',
  'Este producto aún no tiene lotes. Toca "Agregar lote" para registrar su fecha de vencimiento y cantidad.':
      'This product has no batches yet. Tap "Add batch" to record its expiry date and quantity.',
  'Agregar lote':
      'Add batch',
  'Editar producto':
      'Edit product',
  'Usuario (Sin tiendas)':
      'User (no stores)',
  'Trabajador en {0}':
      'Employee at {0}',
  'No se pudo cargar el perfil: {0}':
      'Couldn\'t load the profile: {0}',
  'Nueva Tienda':
      'New store',
  'Crear':
      'Create',
  'Tienda \'{0}\' creada':
      'Store \'{0}\' created',
  'Espera a que cargue tu perfil':
      'Wait for your profile to load',
  'Te has unido a la tienda':
      'You have joined the store',
  'Editar Tienda':
      'Edit store',
  'Actualizar':
      'Update',
  'Tienda actualizada':
      'Store updated',
  'Solo el administrador puede eliminar la tienda.':
      'Only the administrator can delete the store.',
  'Eliminar Tienda':
      'Delete store',
  '¿Estás seguro de que deseas eliminar la sucursal \'{0}\'?':
      'Are you sure you want to delete the branch \'{0}\'?',
  '¿Estás seguro de que deseas eliminar \'{0}\'? Se borrará toda la información, incluyendo personal, productos y sucursales.':
      'Are you sure you want to delete \'{0}\'? All its information will be erased, including staff, products and branches.',
  'Sucursal eliminada':
      'Branch deleted',
  'Tienda y toda su información eliminada':
      'Store and all its information deleted',
  'No se pudo cambiar de tienda: {0}':
      'Couldn\'t switch stores: {0}',
  'Eliminar Personal':
      'Remove staff member',
  '¿Estás seguro de que deseas eliminar a \'{0}\' de esta tienda?':
      'Are you sure you want to remove \'{0}\' from this store?',
  '{0} eliminado':
      '{0} removed',
  'Código copiado: {0}':
      'Code copied: {0}',
  'Mi Perfil':
      'My Profile',
  'Unirse a Tienda':
      'Join store',
  'Mis Minisupers':
      'My stores',
  '+ Agregar':
      '+ Add',
  'Aún no perteneces a ninguna tienda.':
      'You don\'t belong to any store yet.',
  '{0} (Actual)':
      '{0} (Current)',
  'Editar':
      'Edit',
  'Eliminar':
      'Delete',
  'Sucursales vinculadas':
      'Linked branches',
  'Otras de mis tiendas':
      'My other stores',
  'Tocar para ver opciones':
      'Tap to see options',
  'Seleccionar':
      'Select',
  'Administrar Personal':
      'Manage staff',
  'No hay personal registrado.':
      'No staff registered.',
  'Código: {0}':
      'Code: {0}',
  'No se encontró información del producto':
      'No product information was found',
  'Error de red: {0}':
      'Network error: {0}',
  'La linterna no está disponible':
      'The flashlight is not available',
  'Escanear producto':
      'Scan product',
  'Escanea el código de barras del producto':
      'Scan the product\'s barcode',
  'Buscando producto...':
      'Looking up product...',
  'Coloca el código de barras dentro del marco':
      'Place the barcode inside the frame',
  'Apagar':
      'Turn off',
  'Linterna':
      'Flashlight',
  'Instrucciones':
      'Instructions',
  '1. Enfoca el código de barras':
      '1. Focus on the barcode',
  '2. Asegúrate de tener buena iluminación':
      '2. Make sure there is good lighting',
  '3. Mantén el dispositivo estable':
      '3. Hold the device steady',
  'No tienes una tienda vinculada':
      'You don\'t have a linked store',
  'Error al cargar: {0}':
      'Error loading: {0}',
  'Cámara':
      'Camera',
  'Galería':
      'Gallery',
  'Quitar foto':
      'Remove photo',
  'No se pudo obtener la foto: {0}':
      'Couldn\'t get the photo: {0}',
  'Escribe el nombre del producto':
      'Enter the product name',
  'Ya existe un producto con ese nombre':
      'A product with that name already exists',
  'Producto actualizado':
      'Product updated',
  'Producto creado. Ahora agrega su primer lote.':
      'Product created. Now add its first batch.',
  'No se pudo guardar: {0}':
      'Couldn\'t save: {0}',
  'Eliminar producto':
      'Delete product',
  '¿Deseas eliminar "{0}" y todos sus lotes del inventario?':
      'Delete "{0}" and all its batches from the inventory?',
  'Producto eliminado':
      'Product deleted',
  'Los cambios se aplican a todos sus lotes':
      'Changes apply to all its batches',
  'Registra el producto; luego le agregas sus lotes':
      'Register the product; then add its batches',
  'Nombre del producto *':
      'Product name *',
  'Ej. Leche Chiricana':
      'e.g. Whole milk',
  '"{0}" ya está registrado.':
      '"{0}" is already registered.',
  'Presentación (tamaño)':
      'Size',
  'Ej. 946 ml, 1 litro, 500 g':
      'e.g. 946 ml, 1 liter, 500 g',
  'Guardar cambios':
      'Save changes',
  'Guardar producto':
      'Save product',
  'Eliminar producto y sus lotes':
      'Delete product and its batches',
  '¿Ya está registrado?':
      'Already registered?',
  'Toca un producto para agregarle un lote nuevo':
      'Tap a product to add a new batch to it',
  'Agregar foto':
      'Add photo',
  'Opcional':
      'Optional',
  'Las notificaciones están desactivadas. No recibirás alertas de vencimiento.':
      'Notifications are turned off. You won\'t receive expiry alerts.',
  'No se encontró el producto':
      'Product not found',
  'Indica la fecha de vencimiento y la cantidad':
      'Enter the expiry date and quantity',
  'Lote actualizado':
      'Batch updated',
  'Lote agregado':
      'Batch added',
  'Enviando notificación de prueba...':
      'Sending test notification...',
  'Probar notificación':
      'Test notification',
  'Editar lote {0}':
      'Edit batch {0}',
  'Fecha de vencimiento y cantidad':
      'Expiry date and quantity',
  'Cantidad *':
      'Quantity *',
  'Ej. 10':
      'e.g. 10',
  'Guardar lote':
      'Save batch',
  'Cancelar':
      'Cancel',
  'Fecha de vencimiento *':
      'Expiry date *',
  'Selecciona la fecha':
      'Select the date',
  'La contraseña debe tener al menos 6 caracteres':
      'The password must be at least 6 characters long',
  'Registro exitoso':
      'Registration successful',
  'Crear Cuenta':
      'Create account',
  'Únete a Zentory y controla tus productos':
      'Join Zentory and keep track of your products',
  'Nombre completo':
      'Full name',
  'Ej. Juan Pérez':
      'e.g. John Smith',
  'Registrarse':
      'Sign up',
  '¿Ya tienes cuenta? ':
      'Already have an account? ',
  'Inicia sesión':
      'Sign in',
  'No se pudo comprobar tu tienda. Revisa tu conexión a internet.':
      'Couldn\'t check your store. Check your internet connection.',
  'Reintentar':
      'Retry',
  'Ajustes de cuenta':
      'Account settings',
  'Gestiona tu perfil y preferencias':
      'Manage your profile and preferences',
  'Editar Perfil y Tienda':
      'Edit profile and store',
  'Notificaciones':
      'Notifications',
  'Avisar cuando un producto esté por vencer':
      'Alert me when a product is about to expire',
  'Configurar notificaciones':
      'Set up notifications',
  'Permisos, batería y prueba de alertas':
      'Permissions and battery',
  'Ayuda':
      'Help',
  'Cerrar Sesión':
      'Sign out',
  'Crear una nueva tienda':
      'Create a new store',
  'Te has unido a {0}':
      'You have joined {0}',
  '¡Bienvenido a Zentory!':
      'Welcome to Zentory!',
  'Para comenzar a gestionar tus productos, necesitas estar vinculado a una tienda.':
      'To start managing your products, you need to be linked to a store.',
  'Configura tu propio inventario':
      'Set up your own inventory',
  'Unirse a una tienda':
      'Join a store',
  'Ingresa con un código de invitación':
      'Join with an invitation code',
  'Para comenzar, necesitas estar vinculado a un Minisuper.':
      'To get started, you need to be linked to a store.',
  'Crear mi propio Minisuper':
      'Create my own store',
  'Unirse con código de invitación':
      'Join with invitation code',
  'Atrás':
      'Back',
  'Lote':
      'Batch',
  'Vence':
      'Expires',
  'Sin fecha':
      'No date',
  'Cantidad':
      'Quantity',
  'Lote {0}':
      'Batch {0}',
  'Fecha de vencimiento':
      'Expiry date',
  '{0} unidades':
      '{0} units',
  'Presentación':
      'Size',
  'Fecha de registro':
      'Registration date',
  'Editar lote':
      'Edit batch',
  'Cerrar':
      'Close',
  'No se pudo abrir la pantalla automáticamente. Ábrela desde los Ajustes del teléfono.':
      'Couldn\'t open the screen automatically. Open it from the phone\'s Settings.',
  'Tu {0} puede cerrar Zentory en segundo plano y bloquear las alertas de vencimiento.':
      'Your {0} may close Zentory in the background and block expiry alerts.',
  'teléfono':
      'phone',
  'Revisa estos ajustes para recibir las alertas de vencimiento aunque la app esté cerrada.':
      'Check these settings to receive expiry alerts even when the app is closed.',
  'La última vez Zentory se cerró desde Recientes y el sistema la detuvo: mientras está así no recibe alertas. Fíjala con el candado en Recientes para que no vuelva a pasar.':
      'Last time Zentory was closed from Recents and the system stopped it: while stopped it receives no alerts. Lock it in Recents so it doesn\'t happen again.',
  'Permitir notificaciones':
      'Allow notifications',
  'Zentory necesita permiso para mostrar alertas. Activa también "Pantalla de bloqueo", "Banners" y el sonido.':
      'Zentory needs permission to show alerts. Also turn on "Lock screen", "Banners" and sound.',
  'Revisar':
      'Review',
  'Permitir':
      'Allow',
  'Alarmas y recordatorios':
      'Alarms & reminders',
  'Permite que las alertas lleguen a la hora exacta.':
      'Lets alerts arrive at the exact time.',
  'Sin restricciones de batería':
      'No battery restrictions',
  'Evita que el sistema detenga Zentory para ahorrar batería. Se abrirá la información de la app: entra en "Batería" y elige "Sin restricciones".':
      'Prevents the system from stopping Zentory to save battery. The app info screen will open: go to "Battery" and choose "Unrestricted".',
  'Inicio automático y segundo plano':
      'Auto-start and background',
  'Revisado':
      'Checked',
  'Revisar a mano':
      'Check manually',
  'Abrir ajustes':
      'Open settings',
  'Abrir la información de la app':
      'Open app info',
  'Listo':
      'Done',
  'Pendiente':
      'Pending',
  'Ocurrió un error: {0}':
      'An error occurred: {0}',
  'Nombre del Minisuper':
      'Store name',
  'Ubicación / Dirección':
      'Location / Address',
  'Unirse a una Tienda':
      'Join a store',
  'Unirse':
      'Join',
  'Código de Invitación':
      'Invitation code',
  'Sin fecha de vencimiento':
      'No expiry date',
  'Venció ayer':
      'Expired yesterday',
  'Venció hace {0} días':
      'Expired {0} days ago',
  'Vence hoy':
      'Expires today',
  'Vence mañana':
      'Expires tomorrow',
  'Vence en {0} días':
      'Expires in {0} days',
  'Este correo ya está registrado. Intenta iniciar sesión.':
      'This email is already registered. Try signing in.',
  'El formato del correo electrónico no es válido.':
      'The email format is not valid.',
  'Correo o contraseña incorrectos':
      'Incorrect email or password',
  'Demasiados intentos. Intenta más tarde.':
      'Too many attempts. Try again later.',
  'Sin conexión a internet':
      'No internet connection',
  'Error: {0}':
      'Error: {0}',
  'Debes iniciar sesión':
      'You must sign in',
  'El nombre de la tienda es obligatorio':
      'The store name is required',
  'El nombre no puede contener "/"':
      'The name can\'t contain "/"',
  'Ya existe una tienda llamada "{0}"':
      'A store named "{0}" already exists',
  'El código es obligatorio':
      'The code is required',
  'Código inválido':
      'Invalid code',
  'Solo el administrador de la tienda puede eliminar sucursales.':
      'Only the store\'s administrator can delete branches.',
  'Solo el administrador de la tienda puede eliminarla.':
      'Only the store\'s administrator can delete it.',
  'El nombre del producto es obligatorio':
      'The product name is required',
  'Ya existe un producto llamado "{0}"':
      'A product named "{0}" already exists',
  'Está cerca de vencer (3 días)':
      'Expires soon (3 days)',
  'Prueba de Zentory: ¡Las notificaciones están funcionando correctamente! 🎉':
      'Zentory test: notifications are working correctly! 🎉',
  'Prueba programada de Zentory: si ves esto con la app cerrada, las alertas de vencimiento te llegarán. ✅':
      'Zentory scheduled test: if you see this with the app closed, you\'ll receive expiry alerts. ✅',
  'Ajustes > Apps > Gestión de apps > Zentory > Uso de batería: activa "Permitir actividad en segundo plano" y "Permitir inicio automático". También puedes fijar Zentory en Recientes (mantén pulsada la tarjeta y toca el candado).':
      'Settings > Apps > App management > Zentory > Battery usage: turn on "Allow background activity" and "Allow auto launch". You can also lock Zentory in Recents (long-press its card and tap the padlock).',
  'Ajustes > Apps > Administrar apps > Zentory: activa "Inicio automático" y en "Ahorro de batería" elige "Sin restricciones".':
      'Settings > Apps > Manage apps > Zentory: turn on "Autostart" and under "Battery saver" choose "No restrictions".',
  'Ajustes > Batería > Consumo en segundo plano: permite Zentory. En i Manager > Administrador de apps > Inicio automático, actívalo.':
      'Settings > Battery > Background power consumption: allow Zentory. In i Manager > App manager > Autostart, turn it on.',
  'Ajustes > Batería > Inicio de apps > Zentory: desactiva "Gestionar automáticamente" y activa las tres opciones.':
      'Settings > Battery > App launch > Zentory: turn off "Manage automatically" and turn on all three options.',
  'En los ajustes de la app, permite el inicio automático y la actividad en segundo plano, y quita cualquier restricción de batería.':
      'In the app\'s settings, allow auto-start and background activity, and remove any battery restriction.',
  'Producto Desconocido':
      'Unknown product',
  'Buen estado':
      'Good condition',
  'Por vencer':
      'Expiring soon',
  'Vencido':
      'Expired',
  'Todos':
      'All',
  'Sin lotes':
      'No batches',
  'Próximo a vencer':
      'Expiring soonest',
  'Nombre (A–Z)':
      'Name (A–Z)',
  'Mayor cantidad':
      'Highest quantity',
  'Inicio':
      'Home',
  'Calendario':
      'Calendar',
  'LUN':
      'MON',
  'MAR':
      'TUE',
  'MIÉ':
      'WED',
  'JUE':
      'THU',
  'VIE':
      'FRI',
  'SÁB':
      'SAT',
  'DOM':
      'SUN',
  'Administrador Principal':
      'Main administrator',
  'Administrador':
      'Administrator',
  'Trabajador':
      'Employee',
  'Cargando...':
      'Loading...',
  'Usuario':
      'User',
  'Control de caducidad':
      'Expiry control',
  'Agregar Nuevo Minisuper':
      'Add new store',
  'Alerta de Vencimiento':
      'Expiry alert',
  'Apariencia':
      'Appearance',
  'Modo oscuro':
      'Dark mode',
  'Modo claro':
      'Light mode',
  'Idioma':
      'Language',
  'Elige el idioma de la aplicación':
      'Choose the app language',
  'Ese código de barras ya pertenece a "{0}"':
      'That barcode already belongs to "{0}"',
  '"{0}" ya está registrado. Agrega un lote nuevo.':
      '"{0}" is already registered. Add a new batch.',
  'Código guardado. No se encontró información del producto; escribe el nombre y el tamaño.':
      'Code saved. No product information was found; enter the name and size.',
  'Código de barras':
      'Barcode',
  'Escanear código':
      'Scan code',
  'Escanear código de barras':
      'Scan barcode',
  'Toca el botón \'+\' para agregar un producto. En el formulario puedes escanear su código de barras: si el producto ya está registrado, pasarás directo a agregarle un lote.':
      'Tap the \'+\' button to add a product. In the form you can scan its barcode: if the product is already registered, you\'ll go straight to adding a batch.',
  'Ve a Configuración > Privacidad y Seguridad > Cambiar Contraseña, o usa "¿Olvidaste tu contraseña?" en la pantalla de inicio de sesión. Te llegará un correo para crear una nueva.':
      'Go to Settings > Privacy & Security > Change password, or use "Forgot your password?" on the sign-in screen. You\'ll receive an email to create a new one.',
  'Código de barras *':
      'Barcode *',
  'Escanéalo o escríbelo':
      'Scan it or type it',
  'La suscripción de esta tienda está vencida. Puedes ver tu inventario, pero no agregar ni editar productos hasta renovarla.':
      'This store\'s subscription has expired. You can view your inventory, but you can\'t add or edit products until it\'s renewed.',
  'Hola, quiero renovar la suscripción de Zentory de la tienda {0}.':
      'Hi, I\'d like to renew the Zentory subscription for the store {0}.',
  'Tu suscripción vence pronto':
      'Your subscription expires soon',
  'Vence el {0}. Renuévala para seguir agregando y editando productos.':
      'It expires on {0}. Renew it to keep adding and editing products.',
  'Tu suscripción venció':
      'Your subscription has expired',
  'Venció el {0}. Tienes unos días de gracia antes de que la tienda pase a solo lectura.':
      'It expired on {0}. You have a few grace days before the store becomes read-only.',
  'Suscripción suspendida':
      'Subscription suspended',
  'Puedes ver tu inventario, pero no agregar ni editar productos. Renueva la suscripción para reactivar la tienda.':
      'You can view your inventory, but you can\'t add or edit products. Renew the subscription to reactivate the store.',
  'Renovar por WhatsApp':
      'Renew via WhatsApp',
};

const Map<String, String> _zh = {
  'Hola, quiero consultar o pagar la suscripción de Zentory de la tienda {0}.':
      '你好，我想查询或支付 {0} 店铺的 Zentory 订阅费用。',
  'Suscripción y pagos':
      '订阅与付款',
  'No se pudo cargar la suscripción. Revisa tu conexión a internet.':
      '无法加载订阅信息。请检查网络连接。',
  'No perteneces a ninguna tienda.':
      '您不属于任何店铺。',
  'Plan mensual de Zentory':
      'Zentory 月度套餐',
  'Próximo pago':
      '下次付款',
  'Aviso de pago desde':
      '付款提醒开始于',
  'Último día de gracia':
      '宽限期最后一天',
  'Después, la tienda queda en solo lectura':
      '之后，店铺将变为只读',
  'Agregar y editar productos':
      '添加和编辑商品',
  'Permitido':
      '允许',
  'Bloqueado':
      '已锁定',
  'Último pago':
      '最近一次付款',
  'Registrado el {0}':
      '记录于 {0}',
  'Contactar a Zentory por WhatsApp':
      '通过 WhatsApp 联系 Zentory',
  'Pagar o consultar por WhatsApp':
      '通过 WhatsApp 付款或咨询',
  'Cómo funciona el pago':
      '付款方式说明',
  'Se paga una mensualidad por tienda, al final de cada mes de uso. No hay pago inicial.':
      '每个店铺按月付费，在每个使用月结束时支付。无需预付。',
  'La app te avisa {0} días antes de la fecha de pago.':
      '应用会在付款日前 {0} 天提醒您。',
  'Si la fecha pasa, tienes {0} días de gracia para pagar sin perder nada.':
      '如果过了付款日，您有 {0} 天宽限期付款，不会有任何损失。',
  'Después, la tienda queda en solo lectura: puedes ver tu inventario, pero no agregar ni editar productos.':
      '之后店铺将变为只读：您可以查看库存，但不能添加或编辑商品。',
  'Tus datos nunca se borran. Al registrar el pago, la tienda se reactiva al instante.':
      '您的数据永远不会被删除。付款记录后，店铺会立即恢复。',
  'Historial de pagos':
      '付款记录',
  'No se pudo cargar el historial.':
      '无法加载记录。',
  'Todavía no hay pagos registrados.':
      '暂无付款记录。',
  'El historial de pagos solo lo ve el administrador de la tienda.':
      '只有店铺管理员可以查看付款记录。',
  'Sin pago':
      '免费使用',
  'Zentory le dio a esta tienda uso sin pago. No tiene cobros ni vencimientos.':
      'Zentory 已授予此店铺免费使用，没有任何费用或到期日。',
  'Activa':
      '有效',
  'Tu tienda todavía no tiene fechas de pago registradas.':
      '您的店铺尚未记录付款日期。',
  'Al día':
      '已付清',
  'Todo en orden. Faltan {0} días para el próximo pago.':
      '一切正常。距离下次付款还有 {0} 天。',
  'El pago vence hoy.':
      '今天是付款截止日。',
  'El pago vence en {0} días.':
      '{0} 天后付款到期。',
  'Vencida (en gracia)':
      '已逾期（宽限期内）',
  'El pago venció. La tienda sigue funcionando hasta el {0}.':
      '付款已逾期。店铺可继续使用至 {0}。',
  'Suspendida':
      '已暂停',
  'Puedes ver tu inventario, pero no agregar ni editar productos hasta pagar.':
      '您可以查看库存，但在付款前不能添加或编辑商品。',
  'Hoy':
      '今天',
  'Mañana':
      '明天',
  'En {0} días':
      '{0} 天后',
  '1 mes':
      '1 个月',
  '{0} meses':
      '{0} 个月',
  'cubre hasta el {0}':
      '有效期至 {0}',
  'Solicitud enviada':
      '申请已发送',
  'No se pudo enviar la solicitud. Revisa tu conexión.':
      '无法发送申请。请检查网络连接。',
  'Tu solicitud fue rechazada':
      '您的申请被拒绝',
  'El equipo de Zentory no aprobó tu cuenta. Si crees que es un error, contáctanos o vuelve a enviar la solicitud.':
      'Zentory 团队未批准您的账户。如果您认为有误，请联系我们或重新提交申请。',
  'Solicitud rechazada':
      '申请已拒绝',
  'Tu cuenta está bloqueada':
      '您的账户已被封锁',
  'No puedes usar Zentory con esta cuenta. Contacta a Zentory para más información.':
      '您无法使用此账户登录 Zentory。如需了解详情，请联系 Zentory。',
  'Cuenta bloqueada':
      '账户已封锁',
  'Volver a solicitar acceso':
      '重新申请访问',
  'Suscripción':
      '订阅',
  'Estado del pago':
      '付款状态',
  'Próximo pago, días de gracia e historial':
      '下次付款、宽限期和记录',
  'Espere la confirmación de Zentory':
      '请等待 Zentory 确认',
  'Tu cuenta fue creada. El equipo de Zentory debe aprobarla antes de que puedas usar la app. Esta pantalla se quitará sola en cuanto te den acceso.':
      '您的账户已创建。Zentory 团队批准后您才能使用本应用。获得访问权限后，此页面会自动消失。',
  'Esperando aprobación':
      '等待批准',
  'Contactar a Zentory':
      '联系 Zentory',
  'Hola, soy {0} de la tienda {1}. {2}':
      '你好，我是{1}店的{0}。{2}',
  'No se pudo abrir WhatsApp':
      '无法打开 WhatsApp',
  'No se pudo abrir la página de Zentory':
      '无法打开 Zentory 页面',
  'Ayuda y Soporte':
      '帮助与支持',
  '¿En qué podemos ayudarte?':
      '我们能为您做些什么？',
  'Preguntas Frecuentes (FAQ)':
      '常见问题（FAQ）',
  'Contactar Soporte':
      '联系支持',
  'Soporte Técnico':
      '技术支持',
  'Necesito soporte técnico.':
      '我需要技术支持。',
  'Consultas Generales':
      '一般咨询',
  'Tengo una consulta general.':
      '我有一个一般性问题。',
  'No se pudieron cargar los productos: {0}':
      '无法加载商品：{0}',
  'Todos los lotes':
      '所有批次',
  'Lotes que vencen el {0}':
      '{0}到期的批次',
  'Lotes de {0}':
      '{0}的批次',
  '{0} lote':
      '{0} 个批次',
  '{0} lotes':
      '{0} 个批次',
  ' de {0} producto':
      '，共 {0} 种商品',
  ' de {0} productos':
      '，共 {0} 种商品',
  '1 lote vence hoy':
      '1 个批次今天到期',
  '{0} lotes vencen hoy':
      '{0} 个批次今天到期',
  'Revisa tu inventario y evita pérdidas':
      '检查库存，避免损失',
  'Ver todos':
      '查看全部',
  'No hay lotes que venzan en esta fecha':
      '这一天没有到期的批次',
  'Mes anterior':
      '上个月',
  'Mes siguiente':
      '下个月',
  'Sin nombre':
      '无名称',
  '{0} un.':
      '{0} 件',
  '¿Cómo agrego un nuevo producto?':
      '如何添加新商品？',
  '¿Cómo invito a alguien a mi tienda?':
      '如何邀请他人加入我的店铺？',
  'En tu perfil, encontrarás el \'Código de Invitación\' de tu tienda. Compártelo con tus empleados para que puedan unirse desde su propia cuenta.':
      '在个人资料中可以找到店铺的“邀请码”。把它分享给员工，他们就能用自己的账户加入。',
  '¿Puedo tener varias tiendas?':
      '我可以拥有多个店铺吗？',
  'Sí, puedes crear múltiples tiendas o sucursales desde tu perfil y alternar entre ellas en cualquier momento.':
      '可以，您可以在个人资料中创建多个店铺或分店，并随时切换。',
  '¿Cómo cambio mi contraseña?':
      '如何修改密码？',
  'Preguntas Frecuentes':
      '常见问题',
  'No se pudieron cargar los datos: {0}':
      '无法加载数据：{0}',
  'Debes unirte a una tienda antes de poder agregar un producto':
      '添加商品前，您需要先加入一个店铺',
  'Configuración':
      '设置',
  '¡Hola, {0}! 👋':
      '你好，{0}！👋',
  'Aquí tienes el resumen de tu minisúper':
      '这是您店铺的概况',
  'Agregar producto':
      '添加商品',
  'En buen estado':
      '状态良好',
  'Por vencer (7 días)':
      '即将到期（7 天内）',
  'Vencidos':
      '已过期',
  'Total de productos':
      '商品总数',
  '{0} productos vencen mañana':
      '{0} 件商品明天到期',
  'Inventario por estado':
      '按状态分类的库存',
  '¡Aún no tienes una tienda!':
      '您还没有店铺！',
  'Para empezar a gestionar tus productos, necesitas unirte a una tienda o crear la tuya desde tu perfil.':
      '要开始管理商品，请加入一个店铺，或在个人资料中创建自己的店铺。',
  'Configurar Tienda':
      '设置店铺',
  'Productos':
      '商品',
  'Por favor llena todos los campos':
      '请填写所有字段',
  '¡Bienvenido!':
      '欢迎！',
  'Por favor, ingresa tu correo primero':
      '请先输入您的邮箱',
  'Se ha enviado un correo para restablecer tu contraseña':
      '重置密码的邮件已发送',
  'Error al enviar correo: {0}':
      '发送邮件出错：{0}',
  'Logo de Zentory':
      'Zentory 标志',
  '¡Bienvenido de nuevo!':
      '欢迎回来！',
  'Iniciar sesión para continuar':
      '登录以继续',
  'Correo electrónico':
      '电子邮箱',
  'Ingresa tu correo electrónico':
      '请输入您的电子邮箱',
  'Contraseña':
      '密码',
  'Ingresa tu contraseña':
      '请输入您的密码',
  'Ocultar contraseña':
      '隐藏密码',
  'Mostrar contraseña':
      '显示密码',
  '¿Olvidaste tu contraseña?':
      '忘记密码？',
  'Iniciar sesión':
      '登录',
  '¿No tienes una cuenta? ':
      '还没有账户？',
  'Regístrate aquí':
      '在此注册',
  'No se pudo obtener el correo del usuario':
      '无法获取用户邮箱',
  'Se ha enviado un correo para restablecer tu contraseña a {0}':
      '重置密码的邮件已发送至 {0}',
  'Privacidad y Seguridad':
      '隐私与安全',
  'Seguridad de la cuenta':
      '账户安全',
  'Cambiar Contraseña':
      '修改密码',
  'Recibirás un correo para restablecerla':
      '您将收到一封重置邮件',
  'Estado de la cuenta':
      '账户状态',
  'Tu cuenta está protegida por Zentory':
      '您的账户受 Zentory 保护',
  'Datos personales':
      '个人数据',
  'Eliminar mi cuenta':
      '删除我的账户',
  'Opción no disponible en esta versión':
      '此版本暂不支持该选项',
  'Eliminar lote':
      '删除批次',
  '¿Deseas eliminar el lote {0} de "{1}" (vence {2})?':
      '要删除“{1}”的批次 {0}（{2} 到期）吗？',
  '¿Deseas eliminar "{0}" del inventario?':
      '要从库存中删除“{0}”吗？',
  'Eliminado':
      '已删除',
  'No se pudo eliminar: {0}':
      '无法删除：{0}',
  'Filtros':
      '筛选',
  'Limpiar':
      '清除',
  'Estado':
      '状态',
  'Ver resultados':
      '查看结果',
  'Gestiona tus productos, consulta sus lotes y mantén el control de tu inventario.':
      '管理商品，查看批次，掌控库存。',
  'Buscar producto...':
      '搜索商品...',
  'Borrar búsqueda':
      '清除搜索',
  'Ordenar':
      '排序',
  'Limpiar filtros':
      '清除筛选',
  'Inventario vacío.':
      '库存为空。',
  'Sin coincidencias.':
      '没有匹配结果。',
  'Total: ':
      '合计：',
  'Lotes ({0})':
      '批次（{0}）',
  'Este producto aún no tiene lotes. Toca "Agregar lote" para registrar su fecha de vencimiento y cantidad.':
      '该商品还没有批次。点击“添加批次”来登记到期日期和数量。',
  'Agregar lote':
      '添加批次',
  'Editar producto':
      '编辑商品',
  'Usuario (Sin tiendas)':
      '用户（无店铺）',
  'Trabajador en {0}':
      '{0}的员工',
  'No se pudo cargar el perfil: {0}':
      '无法加载个人资料：{0}',
  'Nueva Tienda':
      '新店铺',
  'Crear':
      '创建',
  'Tienda \'{0}\' creada':
      '店铺“{0}”已创建',
  'Espera a que cargue tu perfil':
      '请等待个人资料加载',
  'Te has unido a la tienda':
      '您已加入该店铺',
  'Editar Tienda':
      '编辑店铺',
  'Actualizar':
      '更新',
  'Tienda actualizada':
      '店铺已更新',
  'Solo el administrador puede eliminar la tienda.':
      '只有管理员可以删除店铺。',
  'Eliminar Tienda':
      '删除店铺',
  '¿Estás seguro de que deseas eliminar la sucursal \'{0}\'?':
      '确定要删除分店“{0}”吗？',
  '¿Estás seguro de que deseas eliminar \'{0}\'? Se borrará toda la información, incluyendo personal, productos y sucursales.':
      '确定要删除“{0}”吗？所有信息都将被清除，包括员工、商品和分店。',
  'Sucursal eliminada':
      '分店已删除',
  'Tienda y toda su información eliminada':
      '店铺及其所有信息已删除',
  'No se pudo cambiar de tienda: {0}':
      '无法切换店铺：{0}',
  'Eliminar Personal':
      '移除员工',
  '¿Estás seguro de que deseas eliminar a \'{0}\' de esta tienda?':
      '确定要将“{0}”从此店铺移除吗？',
  '{0} eliminado':
      '{0} 已移除',
  'Código copiado: {0}':
      '已复制代码：{0}',
  'Mi Perfil':
      '我的资料',
  'Unirse a Tienda':
      '加入店铺',
  'Mis Minisupers':
      '我的店铺',
  '+ Agregar':
      '+ 添加',
  'Aún no perteneces a ninguna tienda.':
      '您还没有加入任何店铺。',
  '{0} (Actual)':
      '{0}（当前）',
  'Editar':
      '编辑',
  'Eliminar':
      '删除',
  'Sucursales vinculadas':
      '关联分店',
  'Otras de mis tiendas':
      '我的其他店铺',
  'Tocar para ver opciones':
      '点击查看选项',
  'Seleccionar':
      '选择',
  'Administrar Personal':
      '管理员工',
  'No hay personal registrado.':
      '暂无员工。',
  'Código: {0}':
      '代码：{0}',
  'No se encontró información del producto':
      '未找到商品信息',
  'Error de red: {0}':
      '网络错误：{0}',
  'La linterna no está disponible':
      '手电筒不可用',
  'Escanear producto':
      '扫描商品',
  'Escanea el código de barras del producto':
      '扫描商品条形码',
  'Buscando producto...':
      '正在查找商品...',
  'Coloca el código de barras dentro del marco':
      '将条形码放入框内',
  'Apagar':
      '关闭',
  'Linterna':
      '手电筒',
  'Instrucciones':
      '使用说明',
  '1. Enfoca el código de barras':
      '1. 对准条形码',
  '2. Asegúrate de tener buena iluminación':
      '2. 确保光线充足',
  '3. Mantén el dispositivo estable':
      '3. 保持设备稳定',
  'No tienes una tienda vinculada':
      '您没有关联的店铺',
  'Error al cargar: {0}':
      '加载出错：{0}',
  'Cámara':
      '相机',
  'Galería':
      '相册',
  'Quitar foto':
      '移除照片',
  'No se pudo obtener la foto: {0}':
      '无法获取照片：{0}',
  'Escribe el nombre del producto':
      '请输入商品名称',
  'Ya existe un producto con ese nombre':
      '已存在同名商品',
  'Producto actualizado':
      '商品已更新',
  'Producto creado. Ahora agrega su primer lote.':
      '商品已创建。现在添加第一个批次。',
  'No se pudo guardar: {0}':
      '无法保存：{0}',
  'Eliminar producto':
      '删除商品',
  '¿Deseas eliminar "{0}" y todos sus lotes del inventario?':
      '要从库存中删除“{0}”及其所有批次吗？',
  'Producto eliminado':
      '商品已删除',
  'Los cambios se aplican a todos sus lotes':
      '更改将应用于其所有批次',
  'Registra el producto; luego le agregas sus lotes':
      '先登记商品，然后添加批次',
  'Nombre del producto *':
      '商品名称 *',
  'Ej. Leche Chiricana':
      '例如：全脂牛奶',
  '"{0}" ya está registrado.':
      '“{0}”已登记。',
  'Presentación (tamaño)':
      '规格（大小）',
  'Ej. 946 ml, 1 litro, 500 g':
      '例如：946 毫升、1 升、500 克',
  'Guardar cambios':
      '保存更改',
  'Guardar producto':
      '保存商品',
  'Eliminar producto y sus lotes':
      '删除商品及其批次',
  '¿Ya está registrado?':
      '已经登记过了？',
  'Toca un producto para agregarle un lote nuevo':
      '点击商品为其添加新批次',
  'Agregar foto':
      '添加照片',
  'Opcional':
      '可选',
  'Las notificaciones están desactivadas. No recibirás alertas de vencimiento.':
      '通知已关闭，您将不会收到到期提醒。',
  'No se encontró el producto':
      '未找到商品',
  'Indica la fecha de vencimiento y la cantidad':
      '请填写到期日期和数量',
  'Lote actualizado':
      '批次已更新',
  'Lote agregado':
      '批次已添加',
  'Enviando notificación de prueba...':
      '正在发送测试通知...',
  'Probar notificación':
      '测试通知',
  'Editar lote {0}':
      '编辑批次 {0}',
  'Fecha de vencimiento y cantidad':
      '到期日期和数量',
  'Cantidad *':
      '数量 *',
  'Ej. 10':
      '例如：10',
  'Guardar lote':
      '保存批次',
  'Cancelar':
      '取消',
  'Fecha de vencimiento *':
      '到期日期 *',
  'Selecciona la fecha':
      '选择日期',
  'La contraseña debe tener al menos 6 caracteres':
      '密码至少需要 6 个字符',
  'Registro exitoso':
      '注册成功',
  'Crear Cuenta':
      '创建账户',
  'Únete a Zentory y controla tus productos':
      '加入 Zentory，管理您的商品',
  'Nombre completo':
      '全名',
  'Ej. Juan Pérez':
      '例如：张伟',
  'Registrarse':
      '注册',
  '¿Ya tienes cuenta? ':
      '已有账户？',
  'Inicia sesión':
      '登录',
  'No se pudo comprobar tu tienda. Revisa tu conexión a internet.':
      '无法验证您的店铺，请检查网络连接。',
  'Reintentar':
      '重试',
  'Ajustes de cuenta':
      '账户设置',
  'Gestiona tu perfil y preferencias':
      '管理您的资料和偏好',
  'Editar Perfil y Tienda':
      '编辑资料和店铺',
  'Notificaciones':
      '通知',
  'Avisar cuando un producto esté por vencer':
      '商品即将到期时提醒我',
  'Configurar notificaciones':
      '设置通知',
  'Permisos, batería y prueba de alertas':
      '权限与电池',
  'Ayuda':
      '帮助',
  'Cerrar Sesión':
      '退出登录',
  'Crear una nueva tienda':
      '创建新店铺',
  'Te has unido a {0}':
      '您已加入 {0}',
  '¡Bienvenido a Zentory!':
      '欢迎使用 Zentory！',
  'Para comenzar a gestionar tus productos, necesitas estar vinculado a una tienda.':
      '要开始管理商品，您需要关联一个店铺。',
  'Configura tu propio inventario':
      '建立您自己的库存',
  'Unirse a una tienda':
      '加入店铺',
  'Ingresa con un código de invitación':
      '使用邀请码加入',
  'Para comenzar, necesitas estar vinculado a un Minisuper.':
      '开始前，您需要关联一个店铺。',
  'Crear mi propio Minisuper':
      '创建我自己的店铺',
  'Unirse con código de invitación':
      '使用邀请码加入',
  'Atrás':
      '返回',
  'Lote':
      '批次',
  'Vence':
      '到期',
  'Sin fecha':
      '无日期',
  'Cantidad':
      '数量',
  'Lote {0}':
      '批次 {0}',
  'Fecha de vencimiento':
      '到期日期',
  '{0} unidades':
      '{0} 件',
  'Presentación':
      '规格',
  'Fecha de registro':
      '登记日期',
  'Editar lote':
      '编辑批次',
  'Cerrar':
      '关闭',
  'No se pudo abrir la pantalla automáticamente. Ábrela desde los Ajustes del teléfono.':
      '无法自动打开该页面，请从手机设置中打开。',
  'Tu {0} puede cerrar Zentory en segundo plano y bloquear las alertas de vencimiento.':
      '您的{0}可能会在后台关闭 Zentory 并阻止到期提醒。',
  'teléfono':
      '手机',
  'Revisa estos ajustes para recibir las alertas de vencimiento aunque la app esté cerrada.':
      '检查这些设置，以便在应用关闭时也能收到到期提醒。',
  'La última vez Zentory se cerró desde Recientes y el sistema la detuvo: mientras está así no recibe alertas. Fíjala con el candado en Recientes para que no vuelva a pasar.':
      '上次 Zentory 从“最近任务”中被关闭，系统停止了它：停止期间无法收到提醒。请在“最近任务”中将其加锁，避免再次发生。',
  'Permitir notificaciones':
      '允许通知',
  'Zentory necesita permiso para mostrar alertas. Activa también "Pantalla de bloqueo", "Banners" y el sonido.':
      'Zentory 需要权限才能显示提醒。还请开启“锁屏通知”“横幅”和声音。',
  'Revisar':
      '查看',
  'Permitir':
      '允许',
  'Alarmas y recordatorios':
      '闹钟和提醒',
  'Permite que las alertas lleguen a la hora exacta.':
      '让提醒准时送达。',
  'Sin restricciones de batería':
      '无电池限制',
  'Evita que el sistema detenga Zentory para ahorrar batería. Se abrirá la información de la app: entra en "Batería" y elige "Sin restricciones".':
      '防止系统为省电而停止 Zentory。将打开应用信息页面：进入“电池”，选择“无限制”。',
  'Inicio automático y segundo plano':
      '自启动和后台运行',
  'Revisado':
      '已查看',
  'Revisar a mano':
      '手动检查',
  'Abrir ajustes':
      '打开设置',
  'Abrir la información de la app':
      '打开应用信息',
  'Listo':
      '完成',
  'Pendiente':
      '待处理',
  'Ocurrió un error: {0}':
      '发生错误：{0}',
  'Nombre del Minisuper':
      '店铺名称',
  'Ubicación / Dirección':
      '位置 / 地址',
  'Unirse a una Tienda':
      '加入店铺',
  'Unirse':
      '加入',
  'Código de Invitación':
      '邀请码',
  'Sin fecha de vencimiento':
      '无到期日期',
  'Venció ayer':
      '昨天已过期',
  'Venció hace {0} días':
      '已过期 {0} 天',
  'Vence hoy':
      '今天到期',
  'Vence mañana':
      '明天到期',
  'Vence en {0} días':
      '{0} 天后到期',
  'Este correo ya está registrado. Intenta iniciar sesión.':
      '该邮箱已注册，请尝试登录。',
  'El formato del correo electrónico no es válido.':
      '邮箱格式无效。',
  'Correo o contraseña incorrectos':
      '邮箱或密码错误',
  'Demasiados intentos. Intenta más tarde.':
      '尝试次数过多，请稍后再试。',
  'Sin conexión a internet':
      '无网络连接',
  'Error: {0}':
      '错误：{0}',
  'Debes iniciar sesión':
      '请先登录',
  'El nombre de la tienda es obligatorio':
      '店铺名称为必填项',
  'El nombre no puede contener "/"':
      '名称不能包含“/”',
  'Ya existe una tienda llamada "{0}"':
      '已存在名为“{0}”的店铺',
  'El código es obligatorio':
      '代码为必填项',
  'Código inválido':
      '代码无效',
  'Solo el administrador de la tienda puede eliminar sucursales.':
      '只有店铺管理员可以删除分店。',
  'Solo el administrador de la tienda puede eliminarla.':
      '只有店铺管理员可以删除它。',
  'El nombre del producto es obligatorio':
      '商品名称为必填项',
  'Ya existe un producto llamado "{0}"':
      '已存在名为“{0}”的商品',
  'Está cerca de vencer (3 días)':
      '即将到期（3 天）',
  'Prueba de Zentory: ¡Las notificaciones están funcionando correctamente! 🎉':
      'Zentory 测试：通知功能正常！🎉',
  'Prueba programada de Zentory: si ves esto con la app cerrada, las alertas de vencimiento te llegarán. ✅':
      'Zentory 定时测试：如果在应用关闭时看到此消息，说明您能收到到期提醒。✅',
  'Ajustes > Apps > Gestión de apps > Zentory > Uso de batería: activa "Permitir actividad en segundo plano" y "Permitir inicio automático". También puedes fijar Zentory en Recientes (mantén pulsada la tarjeta y toca el candado).':
      '设置 > 应用 > 应用管理 > Zentory > 耗电管理：开启“允许后台运行”和“允许自启动”。也可以在“最近任务”中锁定 Zentory（长按卡片并点击锁形图标）。',
  'Ajustes > Apps > Administrar apps > Zentory: activa "Inicio automático" y en "Ahorro de batería" elige "Sin restricciones".':
      '设置 > 应用 > 应用管理 > Zentory：开启“自启动”，并在“省电策略”中选择“无限制”。',
  'Ajustes > Batería > Consumo en segundo plano: permite Zentory. En i Manager > Administrador de apps > Inicio automático, actívalo.':
      '设置 > 电池 > 后台耗电管理：允许 Zentory。在 i 管家 > 应用管理 > 自启动 中开启。',
  'Ajustes > Batería > Inicio de apps > Zentory: desactiva "Gestionar automáticamente" y activa las tres opciones.':
      '设置 > 电池 > 应用启动管理 > Zentory：关闭“自动管理”，并开启全部三个选项。',
  'En los ajustes de la app, permite el inicio automático y la actividad en segundo plano, y quita cualquier restricción de batería.':
      '在应用设置中，允许自启动和后台活动，并取消所有电池限制。',
  'Producto Desconocido':
      '未知商品',
  'Buen estado':
      '状态良好',
  'Por vencer':
      '即将到期',
  'Vencido':
      '已过期',
  'Todos':
      '全部',
  'Sin lotes':
      '无批次',
  'Próximo a vencer':
      '最快到期',
  'Nombre (A–Z)':
      '名称（A–Z）',
  'Mayor cantidad':
      '数量最多',
  'Inicio':
      '首页',
  'Calendario':
      '日历',
  'LUN':
      '一',
  'MAR':
      '二',
  'MIÉ':
      '三',
  'JUE':
      '四',
  'VIE':
      '五',
  'SÁB':
      '六',
  'DOM':
      '日',
  'Administrador Principal':
      '主管理员',
  'Administrador':
      '管理员',
  'Trabajador':
      '员工',
  'Cargando...':
      '加载中...',
  'Usuario':
      '用户',
  'Control de caducidad':
      '保质期管理',
  'Agregar Nuevo Minisuper':
      '添加新店铺',
  'Alerta de Vencimiento':
      '到期提醒',
  'Apariencia':
      '外观',
  'Modo oscuro':
      '深色模式',
  'Modo claro':
      '浅色模式',
  'Idioma':
      '语言',
  'Elige el idioma de la aplicación':
      '选择应用语言',
  'Ese código de barras ya pertenece a "{0}"':
      '该条形码已属于“{0}”',
  '"{0}" ya está registrado. Agrega un lote nuevo.':
      '“{0}”已登记，请添加新批次。',
  'Código guardado. No se encontró información del producto; escribe el nombre y el tamaño.':
      '代码已保存。未找到商品信息，请填写名称和规格。',
  'Código de barras':
      '条形码',
  'Escanear código':
      '扫描代码',
  'Escanear código de barras':
      '扫描条形码',
  'Toca el botón \'+\' para agregar un producto. En el formulario puedes escanear su código de barras: si el producto ya está registrado, pasarás directo a agregarle un lote.':
      '点击“+”按钮添加商品。在表单中可以扫描条形码：如果商品已登记，会直接进入添加批次。',
  'Ve a Configuración > Privacidad y Seguridad > Cambiar Contraseña, o usa "¿Olvidaste tu contraseña?" en la pantalla de inicio de sesión. Te llegará un correo para crear una nueva.':
      '前往 设置 > 隐私与安全 > 修改密码，或在登录页面点击“忘记密码？”。您将收到一封用于设置新密码的邮件。',
  'Código de barras *':
      '条形码 *',
  'Escanéalo o escríbelo':
      '扫描或手动输入',
  'La suscripción de esta tienda está vencida. Puedes ver tu inventario, pero no agregar ni editar productos hasta renovarla.':
      '本店铺的订阅已过期。您可以查看库存，但在续订前无法添加或编辑商品。',
  'Hola, quiero renovar la suscripción de Zentory de la tienda {0}.':
      '你好，我想为店铺 {0} 续订 Zentory。',
  'Tu suscripción vence pronto':
      '您的订阅即将到期',
  'Vence el {0}. Renuévala para seguir agregando y editando productos.':
      '将于 {0} 到期。请续订以继续添加和编辑商品。',
  'Tu suscripción venció':
      '您的订阅已过期',
  'Venció el {0}. Tienes unos días de gracia antes de que la tienda pase a solo lectura.':
      '已于 {0} 到期。店铺变为只读前还有几天宽限期。',
  'Suscripción suspendida':
      '订阅已暂停',
  'Puedes ver tu inventario, pero no agregar ni editar productos. Renueva la suscripción para reactivar la tienda.':
      '您可以查看库存，但无法添加或编辑商品。续订后即可重新启用店铺。',
  'Renovar por WhatsApp':
      '通过 WhatsApp 续订',
};
