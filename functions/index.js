/**
 * Cloud Functions de Zentory: avisos push (FCM) de vencimiento.
 *
 * - alertasVencimiento: cada día a las 9:00 (hora de Panamá) revisa los lotes
 *   de cada tienda y avisa a todos los teléfonos registrados en ella
 *   (tiendas/{tiendaId}/dispositivos/{token}): 3 días antes, 1 día antes y el
 *   día del vencimiento. Escribe tiendas/{id}.pushServidor.ultimaEjecucion;
 *   la app usa ese dato para saber que el push está activo y apagar sus
 *   alarmas locales (así no hay avisos dobles).
 * - pruebaPush: envía una notificación de prueba al teléfono que la pide desde
 *   la app (tiendas/{tiendaId}/pruebasPush/{id}).
 *
 * Requiere el plan Blaze de Firebase. Despliegue: ver README.md.
 */
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions, logger} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
setGlobalOptions({region: "us-central1", maxInstances: 2});

/** Zona horaria para decidir qué día es "hoy". */
const TIME_ZONE = "America/Panama";

/** Debe coincidir con el canal creado por la app (NotificationService). */
const CHANNEL_ID = "expiration_notifications_custom_sound";

const {DAY_MS, RULES, todayUtc, parseExpiry, buildBody} = require("./vencimientos");

function androidMessage(title, body, tag, data) {
  return {
    notification: {title, body},
    data,
    android: {
      priority: "high",
      ttl: 12 * 60 * 60 * 1000,
      notification: {
        channelId: CHANNEL_ID,
        icon: "ic_notification",
        color: "#10B981",
        sound: "notification_sound",
        tag,
        visibility: "public",
        defaultVibrateTimings: true,
      },
    },
  };
}

const INVALID_TOKEN_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/** Envía a varios teléfonos y borra los tokens que ya no sirven. */
async function sendToTokens(storeRef, tokens, message) {
  if (tokens.length === 0) return 0;
  let sent = 0;
  for (let i = 0; i < tokens.length; i += 500) {
    const chunk = tokens.slice(i, i + 500);
    const res = await getMessaging().sendEachForMulticast({...message, tokens: chunk});
    sent += res.successCount;
    const invalid = [];
    res.responses.forEach((r, idx) => {
      if (!r.success && INVALID_TOKEN_CODES.has(r.error?.code)) invalid.push(chunk[idx]);
    });
    await Promise.all(invalid.map((t) => storeRef.collection("dispositivos").doc(t).delete()));
  }
  return sent;
}

exports.alertasVencimiento = onSchedule(
  {schedule: "0 9 * * *", timeZone: TIME_ZONE, retryCount: 1},
  async () => {
    const db = getFirestore();
    const today = todayUtc(TIME_ZONE);
    const stores = await db.collection("tiendas").get();

    for (const store of stores.docs) {
      try {
        await store.ref.set(
          {pushServidor: {ultimaEjecucion: FieldValue.serverTimestamp()}},
          {merge: true},
        );
        const devices = await store.ref.collection("dispositivos").get();
        const tokens = devices.docs.map((d) => d.id);
        if (tokens.length === 0) continue;

        const lots = await store.ref.collection("productos").get();
        const byRule = new Map(RULES.map((r) => [r.days, []]));
        lots.forEach((doc) => {
          const p = doc.data();
          const expiry = parseExpiry(p.fechaVencimiento);
          if (expiry === null) return;
          const diff = Math.round((expiry - today) / DAY_MS);
          if (!byRule.has(diff)) return;
          byRule.get(diff).push({
            nombre: String(p.nombre || "").trim() || "Producto",
            cantidad: p.cantidad,
          });
        });

        for (const rule of RULES) {
          const due = byRule.get(rule.days);
          if (due.length === 0) continue;
          const sent = await sendToTokens(
            store.ref,
            tokens,
            androidMessage(
              "Alerta de Vencimiento",
              buildBody(rule, due),
              `vence-${rule.days}`,
              {tipo: "vencimiento", dias: String(rule.days), tiendaId: store.id},
            ),
          );
          logger.info(`Tienda ${store.id}: ${due.length} lotes (${rule.days} días), ${sent} envíos`);
        }
      } catch (e) {
        logger.error(`Tienda ${store.id}`, e);
      }
    }
  },
);

exports.pruebaPush = onDocumentCreated("tiendas/{tiendaId}/pruebasPush/{id}", async (event) => {
  const snap = event.data;
  const data = snap?.data();
  if (!data?.token) return;
  try {
    await getMessaging().send({
      ...androidMessage(
        "Alerta de Vencimiento",
        "Prueba de Zentory: las notificaciones push funcionan ✅",
        "prueba",
        {tipo: "prueba"},
      ),
      token: data.token,
    });
    await snap.ref.set({enviado: true, enviadoEn: FieldValue.serverTimestamp()}, {merge: true});
  } catch (e) {
    logger.error("Prueba push", e);
    await snap.ref.set({error: String(e.message || e)}, {merge: true});
  }
});
