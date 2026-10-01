const test = require("node:test");
const assert = require("node:assert");
const {parseExpiry, buildBody} = require("./vencimientos");

test("lee fechas d/M/yyyy", () => {
  assert.strictEqual(parseExpiry("5/7/2026"), Date.UTC(2026, 6, 5));
  assert.strictEqual(parseExpiry("05/07/2026"), Date.UTC(2026, 6, 5));
  assert.strictEqual(parseExpiry(""), null);
  assert.strictEqual(parseExpiry("Selecciona la fecha"), null);
});

test("arma el texto del aviso", () => {
  const rule = {days: 1, one: "Vence mañana", many: (n) => `${n} lotes vencen mañana`};
  assert.strictEqual(buildBody(rule, [{nombre: "Leche", cantidad: "10"}]),
    "Leche: Vence mañana (10 unidades)");
  assert.strictEqual(
    buildBody(rule, [{nombre: "Leche"}, {nombre: "Pan"}, {nombre: "Jugo"}, {nombre: "Queso"}, {nombre: "Leche"}]),
    "5 lotes vencen mañana: Leche, Pan, Jugo y 1 más");
});
