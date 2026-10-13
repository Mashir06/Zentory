// Lógica de los avisos de vencimiento para la versión web de Zentory.
// No depende de Firebase: así se puede probar sola (ver test/logica.test.js).
//
// Mismas reglas que la app de Android (lib/services/notification_service_io.dart):
// por cada lote se avisa a las 7:00 a. m. 3 días antes, 1 día antes y el día
// del vencimiento.

'use strict';

const ZONA_HORARIA = 'America/Panama';
const DIAS_DE_AVISO = [3, 1, 0];
const MAX_LINEAS = 4;

const TEXTOS = {
  es: {
    titulo: 'Alerta de Vencimiento',
    0: 'Vence hoy',
    1: 'Vence mañana',
    3: 'Está cerca de vencer (3 días)',
    producto: 'Producto',
    mas: (n) => `y ${n} más`,
    resumen: (n) => `${n} productos por vencer`,
    prueba: 'Prueba de Zentory: ¡Las notificaciones están funcionando correctamente! 🎉',
  },
  en: {
    titulo: 'Expiry alert',
    0: 'Expires today',
    1: 'Expires tomorrow',
    3: 'Expires soon (3 days)',
    producto: 'Product',
    mas: (n) => `and ${n} more`,
    resumen: (n) => `${n} products expiring soon`,
    prueba: 'Zentory test: notifications are working correctly! 🎉',
  },
  zh: {
    titulo: '到期提醒',
    0: '今天到期',
    1: '明天到期',
    3: '即将到期（3 天）',
    producto: '产品',
    mas: (n) => `还有 ${n} 个`,
    resumen: (n) => `${n} 个产品即将到期`,
    prueba: 'Zentory 测试：通知功能运行正常！🎉',
  },
};

function textos(idioma) {
  return TEXTOS[idioma] || TEXTOS.es;
}

/** Número de día (días desde 1970) de una fecha d/M/yyyy, o null. */
function diaDeFecha(texto) {
  if (typeof texto !== 'string') return null;
  const partes = texto.trim().split('/');
  if (partes.length !== 3) return null;
  const [d, m, a] = partes.map((p) => Number.parseInt(p, 10));
  if (!Number.isInteger(d) || !Number.isInteger(m) || !Number.isInteger(a)) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return Math.round(Date.UTC(a, m - 1, d) / 86400000);
}

/** Número de día de "hoy" en Panamá. */
function hoyEnPanama(ahora = new Date()) {
  const partes = new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA_HORARIA, year: 'numeric', month: '2-digit', day: '2-digit',
  }).formatToParts(ahora);
  const v = (t) => Number(partes.find((p) => p.type === t).value);
  return Math.round(Date.UTC(v('year'), v('month') - 1, v('day')) / 86400000);
}

/**
 * Lotes de una tienda que hay que avisar hoy.
 * @param {Array<{nombre?: string, fechaVencimiento?: string}>} lotes
 * @param {number} hoy número de día de hoy
 * @returns {Array<{nombre: string, dias: number}>} ordenados: primero los que vencen antes
 */
function avisosDeHoy(lotes, hoy) {
  const avisos = [];
  for (const lote of lotes) {
    const dia = diaDeFecha(lote && lote.fechaVencimiento);
    if (dia === null) continue;
    const dias = dia - hoy;
    if (!DIAS_DE_AVISO.includes(dias)) continue;
    const nombre = String((lote && lote.nombre) || '').trim();
    avisos.push({ nombre, dias });
  }
  avisos.sort((a, b) => a.dias - b.dias || a.nombre.localeCompare(b.nombre, 'es'));
  return avisos;
}

/**
 * Título y texto de la notificación, en el idioma del usuario.
 * Un solo lote: "Leche entera: Vence hoy" (como en Android).
 * Varios: un aviso con la lista, para no llenar el teléfono de notificaciones.
 */
function armarMensaje(avisos, idioma) {
  const t = textos(idioma);
  const linea = (a) => `${a.nombre || t.producto}: ${t[a.dias]}`;
  if (avisos.length === 1) return { titulo: t.titulo, texto: linea(avisos[0]) };
  const lineas = avisos.slice(0, MAX_LINEAS).map(linea);
  if (avisos.length > MAX_LINEAS) lineas.push(t.mas(avisos.length - MAX_LINEAS));
  return { titulo: `${t.titulo} · ${t.resumen(avisos.length)}`, texto: lineas.join('\n') };
}

/**
 * Dispositivos registrados de un usuario: [{ token, idioma }].
 * `usuarios/{uid}.avisosWeb` = { [token]: { idioma, actualizado } }.
 */
function dispositivosDe(usuario) {
  const mapa = (usuario && usuario.avisosWeb) || {};
  return Object.entries(mapa)
    .filter(([token]) => typeof token === 'string' && token.length > 20)
    .map(([token, info]) => ({ token, idioma: (info && info.idioma) || 'es' }));
}

module.exports = {
  ZONA_HORARIA, TEXTOS, textos, diaDeFecha, hoyEnPanama, avisosDeHoy, armarMensaje, dispositivosDe,
};
