// Métricas del panel de administración de Zentory (NubikSoft).
// Solo lee Firestore: tiendas, sus pagos, personal y lotes, y las cuentas de
// usuarios. No modifica nada.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import {
  getAuth, onAuthStateChanged, signOut,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import {
  getFirestore, collection, doc, getDoc, getDocs, getCountFromServer, query,
  where, Timestamp,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import { firebaseConfig, GRACE_DAYS, WARNING_DAYS } from './firebase-config.js';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const $ = (id) => document.getElementById(id);
const DAY = 24 * 60 * 60 * 1000;

/** Mensualidad por tienda cuando suscripcion.monto no está puesto (igual que la app). */
const DEFAULT_FEE = 25;
/** Días que cuentan como "actividad reciente" y "próximos cobros". */
const WINDOW_DAYS = 30;
/** Meses que muestran las gráficas. */
const MONTHS = 12;

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

const money = (n) => `$${n.toLocaleString('es-PA', { minimumFractionDigits: 0, maximumFractionDigits: 2 })}`;
const int = (n) => n.toLocaleString('es-PA');

function fmtDate(date) {
  if (!date) return '—';
  return date.toLocaleDateString('es-PA', { day: 'numeric', month: 'short', year: 'numeric' });
}

function monthKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
}

/** Los últimos [MONTHS] meses, del más antiguo al actual. */
function lastMonths(now) {
  const out = [];
  for (let i = MONTHS - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    out.push({
      key: monthKey(d),
      short: d.toLocaleDateString('es-PA', { month: 'short' }).replace('.', ''),
      long: d.toLocaleDateString('es-PA', { month: 'long', year: 'numeric' }),
    });
  }
  return out;
}

/** Mismo cálculo que la app (lib/models/subscription.dart) y admin.js. */
function statusOf(sub, now = new Date()) {
  if (!sub) return 'sin-registro';
  if (sub.estado === 'exenta') return 'exenta';
  if (sub.estado === 'suspendida') return 'suspendida';
  const until = sub.pagadoHasta?.toDate?.();
  if (!until) return 'sin-registro';
  if (now - until > GRACE_DAYS * DAY) return 'suspendida';
  if (now > until) return 'gracia';
  if (until - now <= WARNING_DAYS * DAY) return 'por-vencer';
  return 'activa';
}

function friendlyError(e) {
  const code = e?.code || '';
  if (code.includes('permission-denied')) {
    return 'Firebase rechazó la lectura. Revisa que las reglas de firestore.rules estén publicadas.';
  }
  return e?.message || String(e);
}

function show(section) {
  for (const id of ['loading', 'not-admin', 'panel']) $(id).hidden = id !== section;
}

// ---------------------------------------------------------------------------
// Sesión: el inicio de sesión se hace en el panel (index.html)
// ---------------------------------------------------------------------------

$('logout').addEventListener('click', async () => {
  await signOut(auth);
  location.href = './';
});

onAuthStateChanged(auth, async (user) => {
  $('who').hidden = !user;
  if (!user) {
    location.href = './';
    return;
  }
  $('who-email').textContent = user.email;
  let isAdmin = false;
  try {
    isAdmin = (await getDoc(doc(db, 'nubiksoft_admins', user.uid))).exists();
  } catch (e) {
    isAdmin = false;
  }
  if (!isAdmin) {
    show('not-admin');
    return;
  }
  show('panel');
  await load();
});

// ---------------------------------------------------------------------------
// Carga de datos
// ---------------------------------------------------------------------------

const count = (q) => getCountFromServer(q).then((r) => r.data().count).catch(() => null);

async function loadStore(snap, since) {
  const data = snap.data();
  const ref = doc(db, 'tiendas', snap.id);
  const [paySnap, staff, lots, recentLots] = await Promise.all([
    getDocs(collection(ref, 'pagos')).catch(() => null),
    count(collection(ref, 'personal')),
    count(collection(ref, 'productos')),
    count(query(collection(ref, 'productos'), where('fechaRegistro', '>=', Timestamp.fromDate(since)))),
  ]);
  const sub = data.suscripcion || null;
  const fee = typeof sub?.monto === 'number' && sub.monto > 0 ? sub.monto : DEFAULT_FEE;
  return {
    id: snap.id,
    nombre: data.nombre || snap.id,
    creada: data.fechaCreacion?.toDate?.() || null,
    sub,
    fee,
    hasta: sub?.pagadoHasta?.toDate?.() || null,
    pagos: paySnap ? paySnap.docs.map((d) => {
      const p = d.data();
      const meses = Number(p.meses) || 1;
      const estimado = typeof p.monto !== 'number';
      return {
        fecha: p.fecha?.toDate?.() || null,
        monto: estimado ? meses * fee : p.monto,
        estimado,
      };
    }) : [],
    personal: staff,
    lotes: lots,
    lotesRecientes: recentLots,
  };
}

async function load() {
  $('updated').textContent = 'Cargando…';
  $('error').hidden = true;
  $('reload').disabled = true;
  const now = new Date();
  const since = new Date(now - WINDOW_DAYS * DAY);
  try {
    const [storeSnap, userSnap] = await Promise.all([
      getDocs(collection(db, 'tiendas')),
      getDocs(collection(db, 'usuarios')).catch(() => null),
    ]);
    const stores = await Promise.all(storeSnap.docs.map((s) => loadStore(s, since)));
    const users = userSnap ? userSnap.docs.map((d) => d.data()) : null;
    render(compute(stores, users, now), now);
    $('updated').textContent = `Actualizado ${now.toLocaleTimeString('es-PA', { hour: 'numeric', minute: '2-digit' })}`;
  } catch (e) {
    $('error').textContent = friendlyError(e);
    $('error').hidden = false;
    $('updated').textContent = '';
  } finally {
    $('reload').disabled = false;
  }
}

$('reload').addEventListener('click', load);

// ---------------------------------------------------------------------------
// Cálculo
// ---------------------------------------------------------------------------

function compute(stores, users, now) {
  const months = lastMonths(now);
  const thisMonth = monthKey(now);
  const prevMonth = monthKey(new Date(now.getFullYear(), now.getMonth() - 1, 1));
  const horizon = new Date(now.getTime() + WINDOW_DAYS * DAY);

  // Grupo comercial de cada tienda.
  //  pagando: funciona y ya registró al menos un pago
  //  prueba:  funciona y todavía no ha pagado nunca (período inicial)
  for (const s of stores) {
    s.status = statusOf(s.sub, now);
    const working = ['activa', 'por-vencer', 'gracia'].includes(s.status);
    if (s.status === 'exenta') s.group = 'exenta';
    else if (s.status === 'suspendida') s.group = 'suspendida';
    else if (s.status === 'sin-registro') s.group = 'sin-registro';
    else if (working && s.pagos.length) s.group = 'pagando';
    else s.group = 'prueba';
  }

  const paying = stores.filter((s) => s.group === 'pagando');
  const trial = stores.filter((s) => s.group === 'prueba');

  // Ingresos por mes (pagos registrados en el panel).
  const revenue = Object.fromEntries(months.map((m) => [m.key, { total: 0, n: 0, est: 0 }]));
  for (const s of stores) {
    for (const p of s.pagos) {
      if (!p.fecha) continue;
      const r = revenue[monthKey(p.fecha)];
      if (!r) continue;
      r.total += p.monto;
      r.n += 1;
      if (p.estimado) r.est += 1;
    }
  }

  // Tiendas nuevas por mes.
  const created = Object.fromEntries(months.map((m) => [m.key, 0]));
  for (const s of stores) {
    if (s.creada && created[monthKey(s.creada)] !== undefined) created[monthKey(s.creada)] += 1;
  }

  // Próximos cobros: tiendas que pagan o están en período inicial, cuya fecha
  // de pago cae en los próximos 30 días o ya pasó (gracia).
  const upcoming = stores
    .filter((s) => (s.group === 'pagando' || s.group === 'prueba') && s.hasta && s.hasta <= horizon)
    .sort((a, b) => a.hasta - b.hasta);

  // Uso de la app.
  const known = stores.filter((s) => s.lotesRecientes !== null);
  const inactive = stores
    .filter((s) => s.group !== 'suspendida' && s.lotesRecientes === 0)
    .sort((a, b) => (b.hasta ? 0 : 1) - (a.hasta ? 0 : 1) || a.nombre.localeCompare(b.nombre, 'es'));
  const sum = (list, key) => list.reduce((t, s) => t + (s[key] ?? 0), 0);

  // Cuentas.
  let accounts = null;
  if (users) {
    const by = (state) => users.filter((u) => (u.estadoAcceso || (u.aprobado === false ? 'pendiente' : 'aprobado')) === state).length;
    accounts = {
      total: users.length,
      pendientes: by('pendiente'),
      aprobadas: by('aprobado'),
      bloqueadas: by('bloqueado') + by('rechazado'),
      nuevas: users.filter((u) => u.fechaRegistro?.toDate?.() >= new Date(now - WINDOW_DAYS * DAY)).length,
    };
  }

  return {
    months,
    stores,
    paying,
    trial,
    mrr: paying.reduce((t, s) => t + s.fee, 0),
    mrrTrial: trial.reduce((t, s) => t + s.fee, 0),
    collected: revenue[thisMonth].total,
    collectedPrev: revenue[prevMonth]?.total ?? 0,
    revenue,
    created,
    newThisMonth: created[thisMonth],
    upcoming,
    expected: upcoming.reduce((t, s) => t + s.fee, 0),
    lots: sum(stores, 'lotes'),
    lotsRecent: sum(known, 'lotesRecientes'),
    staff: sum(stores, 'personal'),
    activeStores: known.filter((s) => s.lotesRecientes > 0).length,
    inactive,
    top: [...stores].filter((s) => s.lotes).sort((a, b) => b.lotes - a.lotes).slice(0, 5),
    accounts,
  };
}

// ---------------------------------------------------------------------------
// Pintado
// ---------------------------------------------------------------------------

const GROUPS = [
  { id: 'pagando', label: 'Pagando', cls: 's-activa', hint: 'Funcionan y ya han pagado' },
  { id: 'prueba', label: 'Período inicial', cls: 's-trial', hint: 'Todavía no han hecho su primer pago' },
  { id: 'exenta', label: 'Uso sin pago', cls: 's-exenta', hint: 'Les diste Zentory sin cobro' },
  { id: 'suspendida', label: 'Suspendidas', cls: 's-suspendida', hint: 'Por falta de pago o a mano' },
  { id: 'sin-registro', label: 'Sin registro', cls: 's-sin-registro', hint: 'Tiendas antiguas sin suscripción' },
];

function delta(now, before, fmt) {
  if (!before && !now) return '';
  if (!before) return '<span class="delta up">nuevo este mes</span>';
  const pct = Math.round(((now - before) / before) * 100);
  if (pct === 0) return `<span class="delta">igual que el mes pasado (${fmt(before)})</span>`;
  return `<span class="delta ${pct > 0 ? 'up' : 'down'}">${pct > 0 ? '▲' : '▼'} ${Math.abs(pct)}% vs. mes pasado (${fmt(before)})</span>`;
}

function render(m, now) {
  const total = m.stores.length;

  $('kpis').innerHTML = `
    <div class="kpi card">
      <div class="l">Ingreso mensual recurrente</div>
      <div class="n">${money(m.mrr)}</div>
      <div class="sub">${m.paying.length} ${m.paying.length === 1 ? 'tienda pagando' : 'tiendas pagando'}${m.mrrTrial ? ` · +${money(m.mrrTrial)} cuando paguen las de período inicial` : ''}</div>
    </div>
    <div class="kpi card">
      <div class="l">Cobrado en ${esc(m.months.at(-1).long.split(' ')[0])}</div>
      <div class="n">${money(m.collected)}</div>
      <div class="sub">${delta(m.collected, m.collectedPrev, money)}</div>
    </div>
    <div class="kpi card">
      <div class="l">Por cobrar en ${WINDOW_DAYS} días</div>
      <div class="n">${money(m.expected)}</div>
      <div class="sub">${m.upcoming.length} ${m.upcoming.length === 1 ? 'tienda' : 'tiendas'} con pago próximo o vencido</div>
    </div>
    <div class="kpi card">
      <div class="l">Tiendas</div>
      <div class="n">${int(total)}</div>
      <div class="sub">${m.newThisMonth ? `+${m.newThisMonth} este mes · ` : ''}${m.activeStores} con actividad en ${WINDOW_DAYS} días</div>
    </div>`;

  // Ingresos por mes.
  const rev = m.months.map((mo) => ({ ...mo, value: m.revenue[mo.key].total, n: m.revenue[mo.key].n, est: m.revenue[mo.key].est }));
  const revTotal = rev.reduce((t, r) => t + r.value, 0);
  $('rev-total').textContent = `${money(revTotal)} en ${MONTHS} meses`;
  barChart($('rev-chart'), rev, money, (r) => `${r.long}: ${money(r.value)}` +
    (r.n ? ` · ${r.n} ${r.n === 1 ? 'pago' : 'pagos'}` : ' · sin pagos') +
    (r.est ? ` (${r.est} sin monto, calculado con la mensualidad)` : ''));
  const anyEst = rev.some((r) => r.est);
  $('rev-note').hidden = !anyEst;

  // Tiendas nuevas.
  const grow = m.months.map((mo) => ({ ...mo, value: m.created[mo.key] }));
  $('grow-total').textContent = `${int(grow.reduce((t, g) => t + g.value, 0))} en ${MONTHS} meses`;
  barChart($('grow-chart'), grow, int, (g) => `${g.long}: ${g.value} ${g.value === 1 ? 'tienda nueva' : 'tiendas nuevas'}`, { integer: true });

  // Estado de las tiendas.
  const max = Math.max(1, ...GROUPS.map((g) => m.stores.filter((s) => s.group === g.id).length));
  $('groups').innerHTML = GROUPS.map((g) => {
    const n = m.stores.filter((s) => s.group === g.id).length;
    if (!n && g.id === 'sin-registro') return '';
    return `<li>
      <div class="gl"><span class="pill ${g.cls}">${g.label}</span><span class="sub">${g.hint}</span></div>
      <div class="gbar"><span class="${g.cls}" style="width:${(n / max) * 100}%"></span></div>
      <strong class="gn">${n}</strong>
    </li>`;
  }).join('');

  // Uso.
  $('usage').innerHTML = `
    <div><dt>Lotes registrados</dt><dd>${int(m.lots)}</dd></div>
    <div><dt>Lotes en ${WINDOW_DAYS} días</dt><dd>${int(m.lotsRecent)}</dd></div>
    <div><dt>Personal en tiendas</dt><dd>${int(m.staff)}</dd></div>
    <div><dt>Promedio de lotes por tienda</dt><dd>${total ? int(Math.round(m.lots / total)) : '—'}</dd></div>
    ${m.accounts ? `
    <div><dt>Cuentas de usuario</dt><dd>${int(m.accounts.total)}<span class="sub"> · +${m.accounts.nuevas} en ${WINDOW_DAYS} días</span></dd></div>
    <div><dt>Cuentas por aprobar</dt><dd>${m.accounts.pendientes ? `<span class="pill s-por-vencer">${m.accounts.pendientes}</span>` : '0'}${m.accounts.bloqueadas ? `<span class="sub"> · ${m.accounts.bloqueadas} rechazadas o bloqueadas</span>` : ''}</dd></div>` : ''}`;
  $('top').innerHTML = m.top.length
    ? m.top.map((s) => `<li><span>${esc(s.nombre)}</span><span class="sub">${int(s.lotes)} lotes</span></li>`).join('')
    : '<li class="sub">Todavía no hay lotes registrados.</li>';

  // Próximos cobros.
  $('upcoming').innerHTML = m.upcoming.length
    ? m.upcoming.map((s) => {
      const days = Math.ceil((s.hasta - now) / DAY);
      const when = days < 0 ? `venció hace ${-days} ${days === -1 ? 'día' : 'días'}`
        : days === 0 ? 'vence hoy' : `en ${days} ${days === 1 ? 'día' : 'días'}`;
      const tag = s.group === 'prueba' ? ' <span class="pill s-trial">primer pago</span>' : '';
      return `<li><div>${esc(s.nombre)}${tag}<div class="sub">${fmtDate(s.hasta)} · ${when}</div></div>
        <strong class="${days < 0 ? 'late' : ''}">${money(s.fee)}</strong></li>`;
    }).join('')
    : `<li class="sub">Ninguna tienda tiene pagos en los próximos ${WINDOW_DAYS} días.</li>`;

  // Tiendas sin actividad.
  $('inactive-count').textContent = m.inactive.length ? `${m.inactive.length}` : '';
  $('inactive').innerHTML = m.inactive.length
    ? m.inactive.map((s) => `<li><div>${esc(s.nombre)}<div class="sub">${s.lotes ? `${int(s.lotes)} lotes en total` : 'Nunca ha registrado lotes'}${s.creada ? ` · creada ${fmtDate(s.creada)}` : ''}</div></div>
        <span class="pill ${GROUPS.find((g) => g.id === s.group)?.cls || ''}">${GROUPS.find((g) => g.id === s.group)?.label || ''}</span></li>`).join('')
    : `<li class="sub">Todas las tiendas registraron lotes en los últimos ${WINDOW_DAYS} días.</li>`;
}

// ---------------------------------------------------------------------------
// Gráfica de barras (SVG, una serie)
// ---------------------------------------------------------------------------

function niceMax(v) {
  if (v <= 0) return 4;
  const pow = 10 ** Math.floor(Math.log10(v));
  for (const k of [1, 2, 2.5, 4, 5, 10]) if (k * pow >= v) return k * pow;
  return 10 * pow;
}

function barChart(el, data, fmt, tip, { integer = false } = {}) {
  // Ancho real del contenedor: así el texto no se encoge en el teléfono.
  const W = Math.max(300, Math.min(640, el.clientWidth || 640)); const H = W < 480 ? 200 : 220;
  const pad = { t: 12, r: 8, b: 26, l: 48 };
  const iw = W - pad.l - pad.r; const ih = H - pad.t - pad.b;
  const peak = Math.max(...data.map((d) => d.value));
  // Conteos: marcas enteras (0, 1, 2, 3, 4…), nunca 0.25.
  const top = integer ? Math.max(4, Math.ceil(peak / 4) * 4) : niceMax(peak);
  const step = iw / data.length;
  const bw = Math.min(28, step * 0.62);
  const every = step < 36 ? 2 : 1; // en pantallas angostas, un mes sí y otro no
  const y = (v) => pad.t + ih - (v / top) * ih;

  const grid = [0, 0.25, 0.5, 0.75, 1].map((f) => {
    const v = top * f; const yy = y(v);
    return `<line x1="${pad.l}" x2="${W - pad.r}" y1="${yy}" y2="${yy}" class="${f ? 'grid' : 'base'}"/>
      <text x="${pad.l - 8}" y="${yy + 4}" class="tick" text-anchor="end">${fmt(Math.round(v * 100) / 100)}</text>`;
  }).join('');

  const bars = data.map((d, i) => {
    const cx = pad.l + step * i + step / 2;
    const h = (d.value / top) * ih;
    const x = cx - bw / 2; const yy = pad.t + ih - h; const r = Math.min(4, h);
    const shape = h > 0
      ? `<path class="bar" d="M${x},${pad.t + ih} V${yy + r} Q${x},${yy} ${x + r},${yy} H${x + bw - r} Q${x + bw},${yy} ${x + bw},${yy + r} V${pad.t + ih} Z"/>`
      : '';
    const last = i === data.length - 1;
    return `<g class="col" data-i="${i}">
      <rect class="hit" x="${pad.l + step * i}" y="${pad.t}" width="${step}" height="${ih}"/>
      ${shape}
      ${last && d.value ? `<text x="${cx}" y="${yy - 6}" class="val" text-anchor="middle">${fmt(d.value)}</text>` : ''}
      ${(data.length - 1 - i) % every === 0 ? `<text x="${cx}" y="${H - 8}" class="tick${last ? ' cur' : ''}" text-anchor="middle">${esc(d.short)}</text>` : ''}
    </g>`;
  }).join('');

  el.innerHTML = `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(el.dataset.label || '')}">${grid}${bars}</svg>
    <div class="tip" hidden></div>
    <table class="sr">${data.map((d) => `<tr><th>${esc(d.long)}</th><td>${fmt(d.value)}</td></tr>`).join('')}</table>`;

  const tipEl = el.querySelector('.tip');
  const svg = el.querySelector('svg');
  const showTip = (g) => {
    el.querySelectorAll('.col.on').forEach((c) => c.classList.remove('on'));
    if (!g) { tipEl.hidden = true; return; }
    g.classList.add('on');
    const d = data[Number(g.dataset.i)];
    tipEl.textContent = tip(d);
    tipEl.hidden = false;
    const box = svg.getBoundingClientRect();
    const scale = box.width / W;
    const cx = (pad.l + step * Number(g.dataset.i) + step / 2) * scale;
    const left = Math.max(0, Math.min(cx - tipEl.offsetWidth / 2, box.width - tipEl.offsetWidth));
    tipEl.style.left = `${left}px`;
  };
  svg.addEventListener('pointermove', (ev) => showTip(ev.target.closest('.col')));
  svg.addEventListener('pointerleave', () => showTip(null));
}
