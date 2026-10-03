// Panel de administración de Zentory (NubikSoft).
// Lee y modifica Firestore directamente; las reglas de seguridad
// (firestore.rules) solo permiten cambiar la suscripción a las cuentas que
// estén en la colección nubiksoft_admins.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, signOut,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js';
import {
  getFirestore, collection, doc, getDoc, getDocs, getCountFromServer, query,
  orderBy, limit, updateDoc, writeBatch, serverTimestamp, Timestamp, deleteField,
} from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js';
import { firebaseConfig, GRACE_DAYS, WARNING_DAYS } from './firebase-config.js';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

const $ = (id) => document.getElementById(id);
const DAY = 24 * 60 * 60 * 1000;

const STATUS = {
  'activa': 'Activa',
  'por-vencer': 'Por vencer',
  'gracia': 'Vencida (gracia)',
  'suspendida': 'Suspendida',
  'sin-registro': 'Sin registro',
  'exenta': 'Sin pago',
};

const FILTERS = [
  { id: 'todas', label: 'Todas', match: () => true },
  { id: 'al-dia', label: 'Al día', match: (s) => s === 'activa' || s === 'sin-registro' },
  { id: 'por-vencer', label: 'Por vencer o vencidas', match: (s) => s === 'por-vencer' || s === 'gracia' },
  { id: 'suspendida', label: 'Suspendidas', match: (s) => s === 'suspendida' },
  { id: 'exenta', label: 'Uso sin pago', match: (s) => s === 'exenta' },
];

let stores = [];
let filter = 'todas';
let current = null; // tienda abierta en el detalle

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------

function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function fmtDate(date) {
  if (!date) return '—';
  return date.toLocaleDateString('es-PA', { day: 'numeric', month: 'short', year: 'numeric' });
}

function addMonths(date, months) {
  const d = new Date(date);
  const day = d.getDate();
  d.setMonth(d.getMonth() + months);
  if (d.getDate() < day) d.setDate(0); // 31 de enero + 1 mes = 28/29 de febrero
  return d;
}

/**
 * Mismo cálculo que la app (lib/models/subscription.dart).
 * 'exenta' es una tienda a la que NubikSoft le dio uso sin pago: no tiene
 * fecha de pago, así que la app la ve como activa y no muestra avisos.
 */
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

function pill(status) {
  return `<span class="pill s-${status}">${STATUS[status]}</span>`;
}

let toastTimer;
function toast(text) {
  const el = $('toast');
  el.textContent = text;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.hidden = true; }, 3500);
}

function friendlyError(e) {
  const code = e?.code || '';
  if (code.includes('invalid-credential') || code.includes('wrong-password') || code.includes('user-not-found')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (code.includes('too-many-requests')) return 'Demasiados intentos. Espera unos minutos.';
  if (code.includes('permission-denied')) {
    return 'Firebase rechazó la operación. Revisa que las reglas de firestore.rules estén publicadas y que tu cuenta esté en nubiksoft_admins.';
  }
  if (code.includes('api-key') || code.includes('referer') || code.includes('unauthorized-domain')) {
    return 'Firebase no acepta esta página. Registra una app web en Firebase y copia su configuración en firebase-config.js.';
  }
  return e?.message || String(e);
}

function show(section) {
  for (const id of ['login', 'not-admin', 'panel']) $(id).hidden = id !== section;
}

// ---------------------------------------------------------------------------
// Sesión
// ---------------------------------------------------------------------------

$('login').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  $('login-error').textContent = '';
  $('login-btn').disabled = true;
  try {
    await signInWithEmailAndPassword(auth, $('email').value.trim(), $('password').value);
  } catch (e) {
    $('login-error').textContent = friendlyError(e);
  } finally {
    $('login-btn').disabled = false;
  }
});

$('logout').addEventListener('click', () => signOut(auth));

$('copy-uid').addEventListener('click', async () => {
  await navigator.clipboard.writeText($('my-uid').textContent);
  toast('ID copiado');
});

onAuthStateChanged(auth, async (user) => {
  $('who').hidden = !user;
  if (!user) {
    show('login');
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
    $('my-uid').textContent = user.uid;
    show('not-admin');
    return;
  }
  show('panel');
  await loadStores();
});

// ---------------------------------------------------------------------------
// Lista de tiendas
// ---------------------------------------------------------------------------

async function loadStore(snap) {
  const data = snap.data();
  const [staffSnap, lotsCount] = await Promise.all([
    getDocs(collection(db, 'tiendas', snap.id, 'personal')).catch(() => null),
    getCountFromServer(collection(db, 'tiendas', snap.id, 'productos'))
      .then((r) => r.data().count).catch(() => null),
  ]);
  const staff = staffSnap ? staffSnap.docs.map((d) => d.data()) : [];
  const admin = staff.find((m) => m.uid && m.uid === data.adminUid)
    || staff.find((m) => m.rol === 'Administrador');
  return {
    id: snap.id,
    nombre: data.nombre || snap.id,
    ubicacion: data.ubicacion || '',
    codigo: data.codigoInvitacion || '',
    adminNombre: data.adminNombre || admin?.nombre || '',
    adminCorreo: admin?.correo || '',
    creada: data.fechaCreacion?.toDate?.() || null,
    personal: staffSnap ? staff.length : null,
    lotes: lotsCount,
    sub: data.suscripcion || null,
    whatsapp: data.contacto?.whatsapp || '',
  };
}

async function loadStores() {
  $('rows').innerHTML = '';
  $('empty').hidden = false;
  $('empty').textContent = 'Cargando tiendas…';
  try {
    const snap = await getDocs(collection(db, 'tiendas'));
    stores = await Promise.all(snap.docs.map(loadStore));
    stores.sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
    render();
  } catch (e) {
    $('empty').textContent = friendlyError(e);
  }
}

$('reload').addEventListener('click', loadStores);
$('search').addEventListener('input', render);

function render() {
  const now = new Date();
  for (const s of stores) s.status = statusOf(s.sub, now);

  $('summary').innerHTML = FILTERS.map((f) => {
    const n = stores.filter((s) => f.match(s.status)).length;
    return `<button type="button" data-filter="${f.id}" aria-pressed="${f.id === filter}">
      <span class="n">${n}</span><span class="l">${f.label}</span></button>`;
  }).join('');

  const term = $('search').value.trim().toLowerCase();
  const active = FILTERS.find((f) => f.id === filter);
  const list = stores.filter((s) => active.match(s.status) && (!term ||
    [s.nombre, s.adminNombre, s.adminCorreo, s.ubicacion].some((v) => v.toLowerCase().includes(term))));

  $('rows').innerHTML = list.map((s) => `
    <tr data-id="${esc(s.id)}" tabindex="0">
      <td><strong>${esc(s.nombre)}</strong><span class="sub">${esc(s.ubicacion)}</span></td>
      <td data-label="Administrador">${esc(s.adminNombre) || '—'}<span class="sub">${esc(s.adminCorreo)}</span></td>
      <td data-label="Personal">${s.personal ?? '—'}</td>
      <td data-label="Lotes">${s.lotes ?? '—'}</td>
      <td data-label="Próximo pago">${s.status === 'exenta' ? 'Sin cobro' : fmtDate(s.sub?.pagadoHasta?.toDate?.())}</td>
      <td>${pill(s.status)}</td>
    </tr>`).join('');

  $('count').textContent = `${list.length} de ${stores.length} tiendas`;
  $('empty').hidden = list.length > 0;
  if (!list.length) {
    $('empty').textContent = stores.length
      ? 'Ninguna tienda coincide con la búsqueda o el filtro.'
      : 'Todavía no hay tiendas registradas en Zentory.';
  }
}

$('summary').addEventListener('click', (ev) => {
  const btn = ev.target.closest('button[data-filter]');
  if (!btn) return;
  filter = btn.dataset.filter;
  render();
});

function openFromRow(ev) {
  const row = ev.target.closest('tr[data-id]');
  if (!row) return;
  if (ev.type === 'keydown' && ev.key !== 'Enter' && ev.key !== ' ') return;
  ev.preventDefault();
  openStore(stores.find((s) => s.id === row.dataset.id));
}
$('rows').addEventListener('click', openFromRow);
$('rows').addEventListener('keydown', openFromRow);

// ---------------------------------------------------------------------------
// Detalle de una tienda
// ---------------------------------------------------------------------------

function nextPaidUntil(store, months) {
  const until = store.sub?.pagadoHasta?.toDate?.();
  const base = until && until > new Date() ? until : new Date();
  return addMonths(base, months);
}

function renderDetail() {
  const s = current;
  s.status = statusOf(s.sub);
  $('dlg-title').textContent = s.nombre;
  $('dlg-sub').innerHTML = `${esc(s.ubicacion)} ${pill(s.status)}`;
  $('dlg-facts').innerHTML = `
    <div><dt>Administrador</dt><dd>${esc(s.adminNombre) || '—'}</dd></div>
    <div><dt>Correo</dt><dd>${esc(s.adminCorreo) || '—'}</dd></div>
    <div><dt>Próximo pago</dt><dd>${s.status === 'exenta' ? 'Sin cobro' : fmtDate(s.sub?.pagadoHasta?.toDate?.())}</dd></div>
    <div><dt>Creada</dt><dd>${fmtDate(s.creada)}</dd></div>
    <div><dt>Personal</dt><dd>${s.personal ?? '—'}</dd></div>
    <div><dt>Lotes registrados</dt><dd>${s.lotes ?? '—'}</dd></div>
    <div><dt>Código de invitación</dt><dd>${esc(s.codigo) || '—'}</dd></div>`;

  const exempt = s.status === 'exenta';
  $('exempt-text').textContent = exempt
    ? 'Esta tienda usa Zentory sin pagar: no tiene fecha de pago y la app no le muestra avisos de cobro.'
    : 'Dale a esta tienda uso de Zentory sin pagar. La app dejará de mostrarle avisos de cobro y nunca quedará suspendida por falta de pago.';
  $('exempt-btn').textContent = exempt ? 'Quitar uso sin pago' : 'Dar uso sin pago';
  $('pay-box').hidden = exempt;
  $('suspend-btn').hidden = exempt;

  const suspended = s.sub?.estado === 'suspendida';
  $('suspend-btn').textContent = suspended ? 'Reactivar tienda' : 'Suspender tienda';
  $('suspend-btn').classList.toggle('btn-danger', !suspended);
  $('wa').value = s.whatsapp;
  updateWaLink();
  updatePreview();
}

function updatePreview() {
  if (!current) return;
  const months = Number($('pay-months').value);
  $('pay-preview').textContent =
    `El próximo pago quedará para el ${fmtDate(nextPaidUntil(current, months))}.`;
}
$('pay-months').addEventListener('change', updatePreview);

function updateWaLink() {
  const phone = $('wa').value.replace(/\D/g, '');
  const link = $('wa-open');
  if (!phone) {
    link.removeAttribute('href');
    link.setAttribute('aria-disabled', 'true');
    return;
  }
  const until = current?.sub?.pagadoHasta?.toDate?.();
  const text = `Hola, te escribimos de NubikSoft. La suscripción de Zentory de la tienda ${current.nombre}` +
    (until ? ` tiene su próximo pago el ${fmtDate(until)}.` : '.');
  link.href = `https://wa.me/${phone}?text=${encodeURIComponent(text)}`;
  link.removeAttribute('aria-disabled');
}
$('wa').addEventListener('input', updateWaLink);

async function loadHistory(storeId) {
  const list = $('history');
  list.innerHTML = '<li class="sub">Cargando…</li>';
  try {
    const snap = await getDocs(query(
      collection(db, 'tiendas', storeId, 'pagos'), orderBy('fecha', 'desc'), limit(12)));
    if (snap.empty) {
      list.innerHTML = '<li class="sub">Todavía no hay pagos registrados.</li>';
      return;
    }
    list.innerHTML = snap.docs.map((d) => {
      const p = d.data();
      const meses = p.meses === 1 ? '1 mes' : `${p.meses} meses`;
      const monto = typeof p.monto === 'number' ? ` · ${p.monto.toFixed(2)} USD` : '';
      return `<li><div>${meses}${monto}<div class="sub">${esc(p.nota || '')}</div></div>
        <div class="sub">${fmtDate(p.fecha?.toDate?.())}<br>próximo: ${fmtDate(p.hasta?.toDate?.())}</div></li>`;
    }).join('');
  } catch (e) {
    list.innerHTML = `<li class="sub">${esc(friendlyError(e))}</li>`;
  }
}

function openStore(store) {
  if (!store) return;
  current = store;
  $('pay-months').value = '1';
  $('pay-amount').value = '';
  $('pay-note').value = '';
  renderDetail();
  loadHistory(store.id);
  $('dlg').showModal();
}

$('dlg').addEventListener('click', (ev) => {
  if (ev.target.closest('[data-close]') || ev.target === $('dlg')) $('dlg').close();
});

async function refreshCurrent() {
  const snap = await getDoc(doc(db, 'tiendas', current.id));
  const fresh = await loadStore(snap);
  const i = stores.findIndex((s) => s.id === current.id);
  stores[i] = fresh;
  current = fresh;
  renderDetail();
  render();
}

$('pay-btn').addEventListener('click', async () => {
  const months = Number($('pay-months').value);
  const amount = $('pay-amount').value === '' ? null : Number($('pay-amount').value);
  const until = nextPaidUntil(current, months);
  const btn = $('pay-btn');
  btn.disabled = true;
  try {
    const storeRef = doc(db, 'tiendas', current.id);
    const batch = writeBatch(db);
    batch.update(storeRef, {
      'suscripcion.estado': 'activa',
      'suscripcion.pagadoHasta': Timestamp.fromDate(until),
      'suscripcion.actualizado': serverTimestamp(),
      'suscripcion.actualizadoPor': auth.currentUser.email,
    });
    batch.set(doc(collection(storeRef, 'pagos')), {
      meses: months,
      monto: amount,
      nota: $('pay-note').value.trim(),
      hasta: Timestamp.fromDate(until),
      fecha: serverTimestamp(),
      registradoPor: auth.currentUser.email,
    });
    await batch.commit();
    toast(`Pago registrado. Próximo pago de ${current.nombre}: ${fmtDate(until)}.`);
    $('pay-amount').value = '';
    $('pay-note').value = '';
    await refreshCurrent();
    loadHistory(current.id);
  } catch (e) {
    toast(friendlyError(e));
  } finally {
    btn.disabled = false;
  }
});

/** Fecha de pago al quitar el uso sin pago: la que tenía antes si sigue vigente, o un mes desde hoy. */
function dateAfterExemption(store) {
  const before = store.sub?.pagadoHastaAnterior?.toDate?.();
  return before && before > new Date() ? before : addMonths(new Date(), 1);
}

$('exempt-btn').addEventListener('click', async () => {
  const exempt = current.status === 'exenta';
  const btn = $('exempt-btn');
  try {
    if (!exempt) {
      if (!confirm(`¿Dar uso sin pago a ${current.nombre}? Podrá usar Zentory sin pagar hasta que se lo quites.`)) return;
      btn.disabled = true;
      const before = current.sub?.pagadoHasta;
      await updateDoc(doc(db, 'tiendas', current.id), {
        'suscripcion.estado': 'exenta',
        'suscripcion.pagadoHasta': deleteField(),
        'suscripcion.pagadoHastaAnterior': before || deleteField(),
        'suscripcion.actualizado': serverTimestamp(),
        'suscripcion.actualizadoPor': auth.currentUser.email,
      });
      await refreshCurrent();
      toast(`${current.nombre} ahora usa Zentory sin pago.`);
    } else {
      const until = dateAfterExemption(current);
      if (!confirm(`¿Quitar el uso sin pago a ${current.nombre}? Su próximo pago quedará para el ${fmtDate(until)}.`)) return;
      btn.disabled = true;
      await updateDoc(doc(db, 'tiendas', current.id), {
        'suscripcion.estado': 'activa',
        'suscripcion.pagadoHasta': Timestamp.fromDate(until),
        'suscripcion.pagadoHastaAnterior': deleteField(),
        'suscripcion.actualizado': serverTimestamp(),
        'suscripcion.actualizadoPor': auth.currentUser.email,
      });
      await refreshCurrent();
      toast(`${current.nombre} vuelve a pagar. Próximo pago: ${fmtDate(until)}.`);
    }
  } catch (e) {
    toast(friendlyError(e));
  } finally {
    btn.disabled = false;
  }
});

$('suspend-btn').addEventListener('click', async () => {
  const suspend = current.sub?.estado !== 'suspendida';
  if (suspend && !confirm(`¿Suspender ${current.nombre}? Su personal podrá ver el inventario, pero no agregar ni editar productos.`)) {
    return;
  }
  try {
    await updateDoc(doc(db, 'tiendas', current.id), {
      'suscripcion.estado': suspend ? 'suspendida' : 'activa',
      'suscripcion.actualizado': serverTimestamp(),
      'suscripcion.actualizadoPor': auth.currentUser.email,
    });
    await refreshCurrent();
    if (suspend) {
      toast(`${current.nombre} quedó suspendida.`);
    } else if (current.status === 'suspendida') {
      toast('Reactivada, pero su fecha de pago ya venció: registra un pago para que vuelva a funcionar.');
    } else {
      toast(`${current.nombre} está activa de nuevo.`);
    }
  } catch (e) {
    toast(friendlyError(e));
  }
});

$('wa-save').addEventListener('click', async () => {
  const phone = $('wa').value.replace(/\D/g, '');
  try {
    await updateDoc(doc(db, 'tiendas', current.id), { 'contacto.whatsapp': phone });
    await refreshCurrent();
    toast('Número guardado.');
  } catch (e) {
    toast(friendlyError(e));
  }
});
