import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';
import '../l10n/strings.dart';

/// Tienda (`tiendas/{id}`) o sucursal (`tiendas/{id}/minisupers/{id}`).
class Store {
  Store({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.codigoInvitacion,
    this.adminUid,
    this.adminNombre,
  });

  final String id;
  final String nombre;
  final String ubicacion;
  final String codigoInvitacion;
  final String? adminUid;
  final String? adminNombre;

  /// `true` si el usuario es el administrador que creó la tienda.
  bool isAdministeredBy({required String uid, String? name}) =>
      (adminUid != null && adminUid == uid) ||
      (adminUid == null && name != null && adminNombre == name);

  factory Store.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Store(
      id: doc.id,
      nombre: (d['nombre'] ?? 'Tienda').toString(),
      ubicacion: (d['ubicacion'] ?? '').toString(),
      codigoInvitacion: (d['codigoInvitacion'] ?? '').toString(),
      adminUid: d['adminUid'] as String?,
      adminNombre: d['adminNombre'] as String?,
    );
  }
}

/// Integrante del personal de una tienda (`tiendas/{id}/personal/{nombre}`).
class StaffMember {
  StaffMember({
    required this.docId,
    required this.uid,
    required this.nombre,
    required this.rol,
  });

  final String docId;
  final String? uid;
  final String nombre;
  final String rol;

  bool get isAdmin => rol == 'Administrador';

  factory StaffMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return StaffMember(
      docId: doc.id,
      uid: d['uid'] as String?,
      nombre: (d['nombre'] ?? doc.id).toString(),
      rol: (d['rol'] ?? 'Trabajador').toString(),
    );
  }
}

/// Error con un mensaje listo para mostrar al usuario.
class ZentoryException implements Exception {
  ZentoryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Acceso a Firestore con la misma estructura de datos que la app Kotlin:
///
/// ```
/// usuarios/{uid}                      nombre, correo, uid, tiendaId, tiendasIds
/// tiendas/{nombreTienda}              nombre, ubicacion, adminUid, adminNombre, codigoInvitacion
///   personal/{nombreUsuario}          uid, nombre, correo, rol, fechaUnion
///   productos/{autoId}                lote: nombre, presentacion, imagen, cantidad,
///                                     fechaVencimiento (d/M/yyyy), fechaRegistro, usuarioId
///   catalogo/{nombreProducto}         producto: nombre, presentacion, imagen
///   minisupers/{id}                   sucursales
/// ```
class ZentoryRepository {
  ZentoryRepository._();
  static final ZentoryRepository instance = ZentoryRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> userRef(String uid) =>
      _db.collection('usuarios').doc(uid);

  CollectionReference<Map<String, dynamic>> get stores =>
      _db.collection('tiendas');

  CollectionReference<Map<String, dynamic>> products(String storeId) =>
      stores.doc(storeId).collection('productos');

  CollectionReference<Map<String, dynamic>> catalog(String storeId) =>
      stores.doc(storeId).collection('catalogo');

  CollectionReference<Map<String, dynamic>> staff(String storeId) =>
      stores.doc(storeId).collection('personal');

  CollectionReference<Map<String, dynamic>> branches(String storeId) =>
      stores.doc(storeId).collection('minisupers');

  // ---------------------------------------------------------------------------
  // Usuario
  // ---------------------------------------------------------------------------

  /// Crea el documento del usuario si todavía no existe (login con correo o
  /// Google).
  Future<void> ensureUserDoc(User user, {String? fallbackEmail}) async {
    final ref = userRef(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'nombre': user.displayName ?? 'Usuario',
        'correo': user.email ?? fallbackEmail ?? '',
        'uid': user.uid,
      });
    }
  }

  Future<void> createUserDoc(User user, String nombre, String correo) {
    return userRef(user.uid).set({
      'nombre': nombre,
      'correo': correo,
      'uid': user.uid,
      'fechaRegistro': Timestamp.now(),
    });
  }

  /// Nombre visible del usuario actual.
  Future<String> currentUserName({String fallback = 'Usuario'}) async {
    final user = currentUser;
    if (user == null) return fallback;
    final doc = await userRef(user.uid).get();
    return (doc.data()?['nombre'] as String?) ??
        user.displayName ??
        user.email ??
        fallback;
  }

  /// Devuelve el ID de la tienda activa del usuario, o `null` si no
  /// pertenece a ninguna (la app le pide entonces crear o unirse a una).
  ///
  /// La tienda guardada en el perfil (`tiendaId`) solo se acepta si todavía
  /// existe y el usuario sigue siendo parte de ella; si la eliminaron o lo
  /// quitaron del personal, se descarta. Si no hay una válida, busca (como
  /// hacía la app Kotlin) una tienda donde sea administrador o trabajador, y
  /// la guarda como activa.
  Future<String?> resolveActiveStoreId() async {
    final user = currentUser;
    if (user == null) return null;
    final userDoc = await userRef(user.uid).get();
    final data = userDoc.data();
    final userName = (data?['nombre'] as String?) ?? user.displayName ?? '';
    final tiendaId = data?['tiendaId'] as String?;
    if (tiendaId != null && tiendaId.isNotEmpty) {
      if (await _belongsToStore(tiendaId, user.uid, userName)) return tiendaId;
      if (userDoc.exists) {
        try {
          await userRef(user.uid).update({
            'tiendaId': FieldValue.delete(),
            'tiendasIds': FieldValue.arrayRemove([tiendaId]),
          });
        } catch (_) {}
      }
    }

    final candidates = {user.uid, if (userName.isNotEmpty) userName}.toList();

    String? found;
    try {
      final asAdmin =
          await stores.where('adminUid', whereIn: candidates).limit(1).get();
      if (asAdmin.docs.isNotEmpty) found = asAdmin.docs.first.id;
    } on FirebaseException catch (e) {
      if (_isNetworkError(e)) rethrow;
    }
    if (found == null) {
      try {
        final asWorker = await _db
            .collectionGroup('personal')
            .where('uid', whereIn: candidates)
            .limit(1)
            .get();
        if (asWorker.docs.isNotEmpty) {
          found = asWorker.docs.first.reference.parent.parent?.id;
        }
      } on FirebaseException catch (e) {
        if (_isNetworkError(e)) rethrow;
      }
    }

    if (found != null && userDoc.exists) {
      try {
        await userRef(user.uid).update({'tiendaId': found});
      } catch (_) {}
    }
    return found;
  }

  /// Errores de Firestore que indican falta de conexión.
  static bool isNetworkError(Object e) =>
      e is FirebaseException && _isNetworkError(e);

  static bool _isNetworkError(FirebaseException e) =>
      e.code == 'unavailable' || e.code == 'deadline-exceeded';

  /// `true` si la tienda existe y el usuario es su administrador o parte de
  /// su personal.
  Future<bool> _belongsToStore(String storeId, String uid, String name) async {
    try {
      return await _checkMembership(storeId, uid, name);
    } on FirebaseException catch (e) {
      // Sin permiso para leerla (p. ej. ya no existe o lo quitaron): no es suya.
      if (e.code == 'permission-denied' || e.code == 'not-found') return false;
      rethrow;
    }
  }

  Future<bool> _checkMembership(String storeId, String uid, String name) async {
    final doc = await stores.doc(storeId).get();
    if (!doc.exists) return false;
    final store = Store.fromDoc(doc);
    if (store.isAdministeredBy(uid: uid, name: name)) return true;
    final byUid =
        await staff(storeId).where('uid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) return true;
    if (name.isEmpty) return false;
    return (await staff(storeId).doc(name).get()).exists;
  }

  Future<void> setActiveStore(String storeId) {
    final uid = currentUser!.uid;
    return userRef(uid).update({'tiendaId': storeId});
  }

  // ---------------------------------------------------------------------------
  // Tiendas
  // ---------------------------------------------------------------------------

  static String _newInvitationCode() {
    const hex = '0123456789ABCDEF';
    final r = Random.secure();
    return List.generate(8, (_) => hex[r.nextInt(16)]).join();
  }

  /// Crea una tienda con el usuario actual como administrador y la deja
  /// activa. Devuelve el ID de la tienda.
  Future<String> createStore({
    required String nombre,
    required String ubicacion,
  }) async {
    final user = currentUser;
    if (user == null) throw ZentoryException(tr('Debes iniciar sesión'));
    final nombreTienda = nombre.trim();
    if (nombreTienda.isEmpty) {
      throw ZentoryException(tr('El nombre de la tienda es obligatorio'));
    }
    if (nombreTienda.contains('/')) {
      throw ZentoryException(tr('El nombre no puede contener "/"'));
    }

    final storeRef = stores.doc(nombreTienda);
    final existing = await storeRef.get();
    if (existing.exists) {
      throw ZentoryException(tr('Ya existe una tienda llamada "{0}"', [nombreTienda]));
    }

    final userName = await currentUserName(fallback: 'Administrador');
    await storeRef.set({
      'nombre': nombreTienda,
      'ubicacion': ubicacion.trim(),
      'adminUid': user.uid,
      'adminNombre': userName,
      'codigoInvitacion': _newInvitationCode(),
      'fechaCreacion': Timestamp.now(),
    });

    await staff(nombreTienda).doc(userName).set({
      'uid': user.uid,
      'nombre': userName,
      'correo': user.email,
      'rol': 'Administrador',
      'fechaUnion': Timestamp.now(),
    });

    await userRef(user.uid).set({
      'tiendaId': nombreTienda,
      'tiendasIds': FieldValue.arrayUnion([nombreTienda]),
    }, SetOptions(merge: true));

    return nombreTienda;
  }

  /// Une al usuario actual a la tienda con el código indicado y la deja
  /// activa. Devuelve el nombre de la tienda.
  Future<String> joinStore(String code) async {
    final user = currentUser;
    if (user == null) throw ZentoryException(tr('Debes iniciar sesión'));
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ZentoryException(tr('El código es obligatorio'));
    }

    final result = await stores
        .where('codigoInvitacion', isEqualTo: normalized)
        .limit(1)
        .get();
    if (result.docs.isEmpty) throw ZentoryException(tr('Código inválido'));

    final tiendaDoc = result.docs.first;
    final userName = await currentUserName(fallback: 'Trabajador');

    await staff(tiendaDoc.id).doc(userName).set({
      'uid': user.uid,
      'nombre': userName,
      'correo': user.email,
      'rol': 'Trabajador',
      'fechaUnion': Timestamp.now(),
    });

    await userRef(user.uid).set({
      'tiendaId': tiendaDoc.id,
      'tiendasIds': FieldValue.arrayUnion([tiendaDoc.id]),
    }, SetOptions(merge: true));

    return (tiendaDoc.data()['nombre'] as String?) ?? tiendaDoc.id;
  }

  Future<void> updateStore({
    required String storeId,
    String? parentStoreId,
    required String nombre,
    required String ubicacion,
  }) {
    final ref = parentStoreId == null
        ? stores.doc(storeId)
        : branches(parentStoreId).doc(storeId);
    return ref.update({'nombre': nombre.trim(), 'ubicacion': ubicacion.trim()});
  }

  /// Elimina una sucursal. Solo el administrador de la tienda principal.
  Future<void> deleteBranch(String parentStoreId, String branchId) async {
    if (!await isStoreAdmin(parentStoreId)) {
      throw ZentoryException(
          tr('Solo el administrador de la tienda puede eliminar sucursales.'));
    }
    await branches(parentStoreId).doc(branchId).delete();
  }

  /// `true` si el usuario actual es administrador de la tienda: la creó
  /// (`adminUid`) o figura con rol "Administrador" en su personal.
  Future<bool> isStoreAdmin(String storeId) async {
    final user = currentUser;
    if (user == null) return false;
    final doc = await stores.doc(storeId).get();
    final store = Store.fromDoc(doc);
    final name = await currentUserName(fallback: '');
    if (store.isAdministeredBy(uid: user.uid, name: name)) return true;
    final staffRes = await staff(storeId).get();
    for (final d in staffRes.docs) {
      final m = StaffMember.fromDoc(d);
      if ((m.uid == user.uid || m.docId == name) && m.isAdmin) return true;
    }
    return false;
  }

  /// Elimina una tienda con todas sus subcolecciones y la quita de los perfiles
  /// de su personal. Solo el administrador puede hacerlo.
  Future<void> deleteStore(String storeId) async {
    if (!await isStoreAdmin(storeId)) {
      throw ZentoryException(
          tr('Solo el administrador de la tienda puede eliminarla.'));
    }
    const subcollections = ['personal', 'productos', 'catalogo', 'minisupers'];
    for (final coll in subcollections) {
      try {
        final snapshot = await stores.doc(storeId).collection(coll).get();
        if (coll == 'personal') {
          for (final doc in snapshot.docs) {
            final staffUid = doc.data()['uid'] as String?;
            if (staffUid == null) continue;
            await _removeStoreFromUser(staffUid, storeId);
          }
        }
        // Los lotes de Firestore admiten hasta 500 operaciones.
        for (var i = 0; i < snapshot.docs.length; i += 450) {
          final batch = _db.batch();
          for (final doc in snapshot.docs.skip(i).take(450)) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      } catch (_) {
        // Se continúa con el resto aunque una subcolección falle.
      }
    }
    await stores.doc(storeId).delete();
  }

  Future<void> _removeStoreFromUser(String uid, String storeId) async {
    try {
      final ref = userRef(uid);
      final doc = await ref.get();
      if (!doc.exists) return;
      final update = <String, dynamic>{
        'tiendasIds': FieldValue.arrayRemove([storeId]),
      };
      if (doc.data()?['tiendaId'] == storeId) {
        update['tiendaId'] = FieldValue.delete();
      }
      await ref.update(update);
    } catch (_) {
      // El "uid" podía ser un nombre en datos antiguos; se ignora.
    }
  }

  /// Quita a un integrante del personal de la tienda.
  Future<void> removeStaffMember(String storeId, StaffMember member) async {
    await staff(storeId).doc(member.docId).delete();
    final uid = member.uid;
    if (uid != null && uid != member.docId) {
      await _removeStoreFromUser(uid, storeId);
    } else {
      // Datos antiguos: buscar el perfil por nombre.
      final res = await _db
          .collection('usuarios')
          .where('nombre', isEqualTo: member.nombre)
          .limit(1)
          .get();
      if (res.docs.isNotEmpty) {
        await _removeStoreFromUser(res.docs.first.id, storeId);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Productos y catálogo
  // ---------------------------------------------------------------------------

  Future<List<Product>> fetchProducts(String storeId) async {
    final result = await products(storeId).get();
    return result.docs.map(Product.fromDoc).toList();
  }

  Future<Map<String, dynamic>?> fetchProductData(
      String storeId, String productId) async {
    final doc = await products(storeId).doc(productId).get();
    return doc.data();
  }

  Future<void> deleteProduct(String storeId, String productId) =>
      products(storeId).doc(productId).delete();

  Future<List<CatalogItem>> fetchCatalog(String storeId) async {
    final res = await catalog(storeId).get();
    return res.docs.map((d) => CatalogItem.fromMap(d.data())).toList();
  }

  // ---------------------------------------------------------------------------
  // Productos (catálogo) y lotes
  //
  // Un **producto** es la ficha del catálogo: nombre, presentación y foto
  // (`tiendas/{id}/catalogo/{nombre}`). Cada **lote** es un registro de
  // `productos` con su fecha de vencimiento y cantidad; lleva copiados el
  // nombre, la presentación y la foto del producto para que se muestren igual
  // en todas las pantallas y en las alertas.
  // ---------------------------------------------------------------------------

  static String _key(String nombre) => nombre.trim().toLowerCase();

  static void _checkName(String nombre) {
    if (nombre.trim().isEmpty) {
      throw ZentoryException(tr('El nombre del producto es obligatorio'));
    }
    if (nombre.contains('/')) {
      throw ZentoryException(tr('El nombre no puede contener "/"'));
    }
  }

  /// Crea un producto nuevo en el catálogo. Lanza [ZentoryException] si ya
  /// existe uno con el mismo nombre.
  Future<void> createProduct({
    required String storeId,
    required String nombre,
    required String presentacion,
    String? imagenBase64,
  }) async {
    final name = nombre.trim();
    _checkName(name);
    if (await findProduct(storeId, name) != null) {
      throw ZentoryException(tr('Ya existe un producto llamado "{0}"', [name]));
    }
    await catalog(storeId).doc(name).set({
      'nombre': name,
      'presentacion': presentacion.trim(),
      'imagen': imagenBase64,
      'fechaCreacion': Timestamp.now(),
    });
  }

  /// Busca un producto del catálogo sin distinguir mayúsculas ni espacios.
  Future<CatalogItem?> findProduct(String storeId, String nombre) async {
    final name = nombre.trim();
    if (name.isEmpty || name.contains('/')) return null;
    final exact = await catalog(storeId).doc(name).get();
    if (exact.data() != null) return CatalogItem.fromMap(exact.data()!);
    final all = await fetchCatalog(storeId);
    for (final item in all) {
      if (_key(item.nombre) == _key(name)) return item;
    }
    return null;
  }

  /// Actualiza nombre, presentación y foto de un producto y de **todos** sus
  /// lotes. [originalName] es el nombre actual del producto.
  Future<void> updateProduct({
    required String storeId,
    required String originalName,
    required String nombre,
    required String presentacion,
    String? imagenBase64,
  }) async {
    final name = nombre.trim();
    _checkName(name);
    final renamed = _key(name) != _key(originalName);
    if (renamed && await findProduct(storeId, name) != null) {
      throw ZentoryException(tr('Ya existe un producto llamado "{0}"', [name]));
    }

    // Ficha del catálogo (se borra la anterior si cambió el nombre).
    final oldDocs = await _catalogDocsFor(storeId, originalName);
    for (final d in oldDocs) {
      if (d.id != name) await d.reference.delete();
    }
    await catalog(storeId).doc(name).set({
      'nombre': name,
      'presentacion': presentacion.trim(),
      'imagen': imagenBase64,
    }, SetOptions(merge: true));

    // Todos los lotes del producto
    final lots = await _lotDocsFor(storeId, originalName);
    for (var i = 0; i < lots.length; i += 450) {
      final batch = _db.batch();
      for (final d in lots.skip(i).take(450)) {
        batch.update(d.reference, {
          'nombre': name,
          'presentacion': presentacion.trim(),
          'imagen': imagenBase64,
        });
      }
      await batch.commit();
    }
  }

  /// Elimina el producto del catálogo y **todos** sus lotes.
  Future<void> deleteProductAndLots(String storeId, String nombre) async {
    final docs = [
      ...await _catalogDocsFor(storeId, nombre),
      ...await _lotDocsFor(storeId, nombre),
    ];
    for (var i = 0; i < docs.length; i += 450) {
      final batch = _db.batch();
      for (final d in docs.skip(i).take(450)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _catalogDocsFor(
      String storeId, String nombre) async {
    final res = await catalog(storeId).get();
    return res.docs
        .where((d) =>
            _key((d.data()['nombre'] ?? d.id).toString()) == _key(nombre))
        .toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _lotDocsFor(
      String storeId, String nombre) async {
    final res = await products(storeId).get();
    return res.docs
        .where((d) => _key((d.data()['nombre'] ?? '').toString()) == _key(nombre))
        .toList();
  }

  /// Agrega un lote (fecha de vencimiento y cantidad) a un producto.
  Future<void> addLot({
    required String storeId,
    required String nombre,
    required String presentacion,
    String? imagenBase64,
    required String cantidad,
    required String fechaVencimiento,
  }) async {
    await products(storeId).add({
      'nombre': nombre.trim(),
      'presentacion': presentacion.trim(),
      'imagen': imagenBase64,
      'cantidad': cantidad,
      'fechaVencimiento': fechaVencimiento,
      'fechaRegistro': Timestamp.now(),
      'usuarioId': currentUser?.uid,
    });
    // Asegura que el producto exista en el catálogo (datos antiguos).
    final name = nombre.trim();
    if (!name.contains('/') && await findProduct(storeId, name) == null) {
      await catalog(storeId).doc(name).set({
        'nombre': name,
        'presentacion': presentacion.trim(),
        'imagen': imagenBase64,
      });
    }
  }

  /// Cambia la fecha de vencimiento y la cantidad de un lote.
  Future<void> updateLot({
    required String storeId,
    required String lotId,
    required String cantidad,
    required String fechaVencimiento,
  }) {
    return products(storeId).doc(lotId).update({
      'cantidad': cantidad,
      'fechaVencimiento': fechaVencimiento,
    });
  }
}
