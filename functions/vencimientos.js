/**
 * Lógica pura de los avisos (sin dependencias de Firebase, para poder
 * probarla con `npm test`).
 */
const DAY_MS = 24 * 60 * 60 * 1000;

const RULES = [
  {days: 3, one: "Está cerca de vencer (3 días)", many: (n) => `${n} lotes vencen en 3 días`},
  {days: 1, one: "Vence mañana", many: (n) => `${n} lotes vencen mañana`},
  {days: 0, one: "Vence hoy", many: (n) => `${n} lotes vencen hoy`},
];

/** Medianoche (UTC) del día de hoy en la zona horaria indicada. */
function todayUtc(timeZone) {
  const s = new Intl.DateTimeFormat("en-CA", {
    timeZone, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(new Date()); // "2026-10-01"
  const [y, m, d] = s.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}

/** Fecha "d/M/yyyy" (como la guarda la app) a medianoche UTC. */
function parseExpiry(value) {
  if (typeof value !== "string") return null;
  const parts = value.trim().split("/");
  if (parts.length !== 3) return null;
  const [d, m, y] = parts.map((n) => parseInt(n, 10));
  if (!d || !m || !y || m > 12 || d > 31) return null;
  return Date.UTC(y, m - 1, d);
}

function buildBody(rule, lots) {
  if (lots.length === 1) {
    const l = lots[0];
    const qty = l.cantidad ? ` (${l.cantidad} unidades)` : "";
    return `${l.nombre}: ${rule.one}${qty}`;
  }
  const names = [...new Set(lots.map((l) => l.nombre))];
  const shown = names.slice(0, 3).join(", ");
  const extra = names.length > 3 ? ` y ${names.length - 3} más` : "";
  return `${rule.many(lots.length)}: ${shown}${extra}`;
}

module.exports = {DAY_MS, RULES, todayUtc, parseExpiry, buildBody};
