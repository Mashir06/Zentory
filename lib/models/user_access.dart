/// Acceso de una cuenta a la app (`usuarios/{uid}`). Lo decide NubikSoft desde
/// el panel web.
///
/// ```
/// aprobado: bool                 true solo cuando tiene acceso
/// estadoAcceso: 'pendiente' | 'aprobado' | 'rechazado' | 'bloqueado'
/// ```
///
/// Las cuentas antiguas no tienen estos campos y siguen entrando.
enum AccessState {
  /// Puede usar la app.
  approved,

  /// Recién registrada, esperando la confirmación de Zentory.
  pending,

  /// NubikSoft rechazó la solicitud; el usuario puede volver a pedirla.
  rejected,

  /// Bloqueada: no puede usar la app ni volver a pedir acceso.
  blocked;

  static const approvedField = 'aprobado';
  static const stateField = 'estadoAcceso';

  static AccessState fromData(Map<String, dynamic>? data) {
    if (data?[approvedField] != false) return AccessState.approved;
    return switch (data?[stateField]) {
      'rechazado' => AccessState.rejected,
      'bloqueado' => AccessState.blocked,
      _ => AccessState.pending,
    };
  }
}
