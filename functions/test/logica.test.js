'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  diaDeFecha, hoyEnPanama, avisosDeHoy, armarMensaje, dispositivosDe,
} = require('../logica');

const hoy = diaDeFecha('13/10/2026');

test('lee fechas d/M/yyyy como la app', () => {
  assert.equal(diaDeFecha('1/1/1970'), 0);
  assert.equal(diaDeFecha('14/10/2026') - hoy, 1);
  assert.equal(diaDeFecha(' 16/10/2026 ') - hoy, 3);
  assert.equal(diaDeFecha('32/1/2026'), null);
  assert.equal(diaDeFecha('2026-10-13'), null);
  assert.equal(diaDeFecha(undefined), null);
});

test('"hoy" se calcula en hora de Panamá (UTC-5)', () => {
  // 13 oct 2026 a las 23:30 en Panamá = 14 oct 04:30 UTC
  assert.equal(hoyEnPanama(new Date('2026-10-14T04:30:00Z')), hoy);
  // 7:00 a. m. en Panamá = 12:00 UTC
  assert.equal(hoyEnPanama(new Date('2026-10-13T12:00:00Z')), hoy);
});

test('avisa 3 días antes, 1 día antes y el mismo día', () => {
  const lotes = [
    { nombre: 'Leche', fechaVencimiento: '13/10/2026' }, // hoy
    { nombre: 'Pan', fechaVencimiento: '14/10/2026' }, // mañana
    { nombre: 'Yogur', fechaVencimiento: '15/10/2026' }, // 2 días: no
    { nombre: 'Queso', fechaVencimiento: '16/10/2026' }, // 3 días
    { nombre: 'Jugo', fechaVencimiento: '12/10/2026' }, // ayer: no
    { nombre: 'Sin fecha', fechaVencimiento: '' },
  ];
  assert.deepEqual(avisosDeHoy(lotes, hoy), [
    { nombre: 'Leche', dias: 0 },
    { nombre: 'Pan', dias: 1 },
    { nombre: 'Queso', dias: 3 },
  ]);
});

test('un solo lote: mismo texto que Android', () => {
  const m = armarMensaje([{ nombre: 'Leche', dias: 1 }], 'es');
  assert.deepEqual(m, { titulo: 'Alerta de Vencimiento', texto: 'Leche: Vence mañana' });
  assert.equal(armarMensaje([{ nombre: '', dias: 0 }], 'en').texto, 'Product: Expires today');
  assert.equal(armarMensaje([{ nombre: 'Leche', dias: 3 }], 'zh').texto, 'Leche: 即将到期（3 天）');
  assert.equal(armarMensaje([{ nombre: 'Leche', dias: 3 }], 'fr').titulo, 'Alerta de Vencimiento');
});

test('varios lotes: un solo aviso con la lista', () => {
  const avisos = ['A', 'B', 'C', 'D', 'E', 'F'].map((nombre) => ({ nombre, dias: 0 }));
  const m = armarMensaje(avisos, 'es');
  assert.equal(m.titulo, 'Alerta de Vencimiento · 6 productos por vencer');
  assert.equal(m.texto, 'A: Vence hoy\nB: Vence hoy\nC: Vence hoy\nD: Vence hoy\ny 2 más');
});

test('lee los navegadores registrados de una cuenta', () => {
  const token = 'x'.repeat(40);
  assert.deepEqual(dispositivosDe({ avisosWeb: { [token]: { idioma: 'en' }, corto: {} } }), [
    { token, idioma: 'en' },
  ]);
  assert.deepEqual(dispositivosDe({}), []);
  assert.deepEqual(dispositivosDe(undefined), []);
});
