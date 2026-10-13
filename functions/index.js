// Funciones de Firebase de Zentory (proyecto zentory-base).
//
// avisosVencimientoWeb  Todos los días a las 7:00 a. m. (hora de Panamá) manda
//                       los avisos de vencimiento a la versión web de la app
//                       (notificaciones push). Avisa 3 días antes, 1 día antes
//                       y el día del vencimiento, igual que la app de Android.
// probarAvisoWeb        Manda una notificación de prueba a los dispositivos
//                       del usuario que la pide (botón en Ajustes de la web).
//
// Quién recibe los avisos: las cuentas con `avisosWebActivos: true` en
// usuarios/{uid}, en cada navegador registrado en `avisosWeb`, con los lotes de
// su tienda activa (`tiendaId`). Los navegadores que ya no existen se borran
// solos.
//
// Requiere el plan Blaze de Firebase. Para publicar (desde la carpeta raíz del
// repositorio):  npx firebase-tools deploy --only functions --project zentory-base

'use strict';

const { setGlobalOptions } = require('firebase-functions/v2');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, FieldPath } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const {
  ZONA_HORARIA, textos, hoyEnPanama, avisosDeHoy, armarMensaje, dispositivosDe,
} = require('./logica');

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 2 });

const db = getFirestore();
const APP_URL = 'https://nubiksoft.com/zentory/app/';
const ICONO = 'https://nubiksoft.com/zentory/app/icons/Icon-192.png';

/** Errores que significan que ese navegador ya no está registrado. */
const TOKEN_INVALIDO = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

function mensajePara(token, titulo, texto) {
  return {
    token,
    notification: { title: titulo, body: texto },
    webpush: {
      notification: { icon: ICONO, tag: 'zentory-vencimientos', renotify: true },
      fcmOptions: { link: APP_URL },
    },
  };
}

/**
 * Envía los mensajes y borra de Firestore los navegadores que ya no existen.
 * @param {Array<{uid: string, token: string, mensaje: object}>} envios
 * @returns {Promise<number>} cuántos se entregaron
 */
async function enviar(envios) {
  let entregados = 0;
  const invalidos = new Map(); // uid -> [tokens]
  for (let i = 0; i < envios.length; i += 500) {
    const lote = envios.slice(i, i + 500);
    const res = await getMessaging().sendEach(lote.map((e) => e.mensaje));
    res.responses.forEach((r, k) => {
      if (r.success) { entregados++; return; }
      const code = r.error && r.error.code;
      if (TOKEN_INVALIDO.has(code)) {
        const { uid, token } = lote[k];
        if (!invalidos.has(uid)) invalidos.set(uid, []);
        invalidos.get(uid).push(token);
      } else {
        logger.warn('No se pudo enviar un aviso', { code, message: r.error && r.error.message });
      }
    });
  }
  for (const [uid, tokens] of invalidos) {
    const update = [];
    for (const token of tokens) update.push(new FieldPath('avisosWeb', token), FieldValue.delete());
    try {
      await db.collection('usuarios').doc(uid).update(...update);
    } catch (e) {
      logger.warn('No se pudieron borrar navegadores viejos', { uid, error: String(e) });
    }
  }
  return entregados;
}

/** Avisos del día para todas las cuentas que los activaron en la web. */
async function avisosDelDia() {
  const hoy = hoyEnPanama();
  const usuarios = await db.collection('usuarios').where('avisosWebActivos', '==', true).get();

  // Cuentas agrupadas por su tienda activa, para leer cada tienda una sola vez.
  const porTienda = new Map();
  for (const doc of usuarios.docs) {
    const u = doc.data();
    if (u.aprobado === false) continue; // cuentas sin acceso a la app
    const tienda = typeof u.tiendaId === 'string' ? u.tiendaId : '';
    const dispositivos = dispositivosDe(u);
    if (!tienda || dispositivos.length === 0) continue;
    if (!porTienda.has(tienda)) porTienda.set(tienda, []);
    porTienda.get(tienda).push({ uid: doc.id, dispositivos });
  }

  const envios = [];
  for (const [tienda, cuentas] of porTienda) {
    let lotes;
    try {
      const snap = await db.collection('tiendas').doc(tienda).collection('productos').get();
      lotes = snap.docs.map((d) => d.data());
    } catch (e) {
      logger.warn('No se pudieron leer los lotes de una tienda', { tienda, error: String(e) });
      continue;
    }
    const avisos = avisosDeHoy(lotes, hoy);
    if (avisos.length === 0) continue;
    for (const { uid, dispositivos } of cuentas) {
      for (const { token, idioma } of dispositivos) {
        const { titulo, texto } = armarMensaje(avisos, idioma);
        envios.push({ uid, token, mensaje: mensajePara(token, titulo, texto) });
      }
    }
  }

  const entregados = envios.length ? await enviar(envios) : 0;
  logger.info('Avisos de vencimiento web', {
    cuentas: usuarios.size, tiendas: porTienda.size, enviados: envios.length, entregados,
  });
}

exports.avisosVencimientoWeb = onSchedule(
  { schedule: '0 7 * * *', timeZone: ZONA_HORARIA, timeoutSeconds: 540, memory: '256MiB' },
  avisosDelDia,
);

exports.probarAvisoWeb = onRequest({ cors: true, memory: '256MiB' }, async (req, res) => {
  if (req.method !== 'POST') { res.status(405).json({ error: 'Usa POST' }); return; }
  const header = req.get('Authorization') || '';
  const idToken = header.startsWith('Bearer ') ? header.slice(7) : '';
  let uid;
  try {
    uid = (await getAuth().verifyIdToken(idToken)).uid;
  } catch (e) {
    res.status(401).json({ error: 'Sesión no válida' });
    return;
  }
  const doc = await db.collection('usuarios').doc(uid).get();
  const dispositivos = dispositivosDe(doc.data());
  if (dispositivos.length === 0) {
    res.status(404).json({ error: 'No hay dispositivos registrados' });
    return;
  }
  const pedido = req.body && typeof req.body.idioma === 'string' ? req.body.idioma : null;
  const envios = dispositivos.map(({ token, idioma }) => {
    const t = textos(pedido || idioma);
    return { uid, token, mensaje: mensajePara(token, t.titulo, t.prueba) };
  });
  const entregados = await enviar(envios);
  res.status(entregados > 0 ? 200 : 410).json({ enviados: envios.length, entregados });
});
