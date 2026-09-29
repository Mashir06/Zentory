import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/product.dart';

/// Tienda (`tiendas/{id}`) o sucursal (`tiendas/{id}/minisupers/{id}`).
class Store {
  Store({
    required this.id,
    required this.nombre,
    required this.ubicacion,
    required this.codigoInvitacion,
  });

  final String id;
  final String nombre;
  final String ubicacion;
  final String codigoInvitacion;

  factory Store.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Store(
      id: doc.id,
      nombre: (d['nombre'] ?? 'Tienda').toString(),
      ubicacion: (d['ubicacion'] ?? '').toString(),
      codigoInvitacion: (d['codigoInvitacion'] ?? '').toString(),
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
///   productos/{autoId}                nombre, categoria, marca, presentacion, cantidad,
///                                     fechaVencimiento (d/M/yyyy), fechaRegistro, imagen, usuarioId
///   catalogo/{nombreProducto}         nombre, categoria, marca, presentacion, imagen
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

  /// Devuelve el ID de la tienda activa del usuario.
  ///
  /// Si el perfil no tiene `tiendaId`, busca (como hacía la app Kotlin) una
  /// tienda donde sea administrador o trabajador, y la guarda como activa.
  Future<String?> resolveActiveStoreId() async {
    final user = currentUser;
    if (user == null) return null;
    final userDoc = await userRef(user.uid).get();
    final data = userDoc.data();
    final tiendaId = data?['tiendaId'] as String?;
    if (tiendaId != null && tiendaId.isNotEmpty) return tiendaId;

    final userName = (data?['nombre'] as String?) ?? user.displayName ?? '';
    final candidates = {user.uid, if (userName.isNotEmpty) userName}.toList();

    String? found;
    final asAdmin =
        await stores.where('adminUid', whereIn: candidates).limit(1).get();
    if (asAdmin.docs.isNotEmpty) {
      found = asAdmin.docs.first.id;
    } else {
      final asWorker = await _db
          .collectionGroup('personal')
          .where('uid', whereIn: candidates)
          .limit(1)
          .get();
      if (asWorker.docs.isNotEmpty) {
        found = asWorker.docs.first.reference.parent.parent?.id;
      }
    }

    if (found != null && userDoc.exists) {
      await userRef(user.uid).update({'tiendaId': found});
    }
    return found;
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
    if (user == null) throw ZentoryException('Debes iniciar sesión');
    final nombreTienda = nombre.trim();
    if (nombreTienda.isEmpty) {
      throw ZentoryException('El nombre de la tienda es obligatorio');
    }
    if (nombreTienda.contains('/')) {
      throw ZentoryException('El nombre no puede contener "/"');
    }

    final storeRef = stores.doc(nombreTienda);
    final existing = await storeRef.get();
    if (existing.exists) {
      throw ZentoryException('Ya existe una tienda llamada "$nombreTienda"');
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
    if (user == null) throw ZentoryException('Debes iniciar sesión');
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw ZentoryException('El código es obligatorio');
    }

    final result = await stores
        .where('codigoInvitacion', isEqualTo: normalized)
        .limit(1)
        .get();
    if (result.docs.isEmpty) throw ZentoryException('Código inválido');

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

  Future<void> deleteBranch(String parentStoreId, String branchId) =>
      branches(parentStoreId).doc(branchId).delete();

  /// Elimina una tienda con todas sus subcolecciones y la quita de los perfiles
  /// de su personal.
  Future<void> deleteStore(String storeId) async {
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

  Future<CatalogItem?> findInCatalog(String storeId, String nombre) async {
    if (nombre.contains('/')) return null;
    final doc = await catalog(storeId).doc(nombre).get();
    final data = doc.data();
    return data == null ? null : CatalogItem.fromMap(data);
  }

  /// Guarda un producto nuevo o actualiza uno existente. Los productos nuevos
  /// también se agregan al catálogo de productos frecuentes.
  Future<void> saveProduct({
    required String storeId,
    String? productId,
    required String nombre,
    required String categoria,
    required String marca,
    required String presentacion,
    required String cantidad,
    required String fechaVencimiento,
    String? imagenBase64,
  }) async {
    final data = <String, dynamic>{
      'nombre': nombre,
      'categoria': categoria,
      'cantidad': cantidad,
      'fechaVencimiento': fechaVencimiento,
      'marca': marca,
      'presentacion': presentacion,
      'usuarioId': currentUser?.uid,
      'imagen': imagenBase64,
    };

    if (productId == null) {
      data['fechaRegistro'] = Timestamp.now();
      await products(storeId).add(data);
      if (!nombre.contains('/')) {
        await catalog(storeId).doc(nombre).set({
          'nombre': nombre,
          'categoria': categoria,
          'marca': marca,
          'presentacion': presentacion,
          'imagen': imagenBase64,
        });
      }
    } else {
      await products(storeId).doc(productId).update(data);
    }
  }
}
