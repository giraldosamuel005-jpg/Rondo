// Ficha médica pública de Rondó (RF-24, RF-25).
//
// El QR abre https://rondo-fb405.web.app/f/{token}. Esta página lee la ficha
// de Firestore (fichas/{token}) con la API REST, sin iniciar sesión: las
// reglas de firestore.rules dejan leer una ficha a quien tenga su token, pero
// no listarlas. Después deja registrada la consulta para que la dueña la vea.
//
// Todo lo que viene de la ficha se pone con textContent, nunca como HTML.
'use strict';

const PROYECTO = 'rondo-fb405';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROYECTO}/databases/(default)/documents`;

const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
  'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

const ERRORES = {
  invalido: ['Este código QR no es válido.', 'Revisa que hayas escaneado el código completo.'],
  revocado: ['Este enlace fue revocado por su dueño.', 'La persona creó un código nuevo o dejó de compartir su ficha.'],
  red: ['No pudimos cargar la ficha.', 'Revisa tu conexión a internet e intenta otra vez.'],
};

const $ = (id) => document.getElementById(id);

/** El token de la URL (/f/{token}), o null si no tiene la forma correcta. */
function tokenDeLaUrl() {
  const m = location.pathname.match(/^\/f\/([0-9a-f]{32})\/?$/);
  return m ? m[1] : null;
}

/** Un valor de la API REST de Firestore a JavaScript normal. */
function valor(v) {
  if (!v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(valor);
  if ('mapValue' in v) return campos(v.mapValue.fields || {});
  return null;
}

function campos(fields) {
  const r = {};
  for (const [k, v] of Object.entries(fields)) r[k] = valor(v);
  return r;
}

function textos(lista) {
  return Array.isArray(lista) ? lista.filter((t) => typeof t === 'string' && t.trim() !== '') : [];
}

/** "1950-03-07" → {edad: 76, texto: "7 de marzo de 1950"} con la fecha de hoy. */
function edadDe(fecha) {
  const m = typeof fecha === 'string' && fecha.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const [anio, mes, dia] = [Number(m[1]), Number(m[2]), Number(m[3])];
  const hoy = new Date();
  const cumplio = hoy.getMonth() + 1 > mes || (hoy.getMonth() + 1 === mes && hoy.getDate() >= dia);
  return { edad: hoy.getFullYear() - anio - (cumplio ? 0 : 1), texto: `${dia} de ${MESES[mes - 1]} de ${anio}` };
}

/** "3001234567" → "+57 300 123 4567" */
function celularBonito(c) {
  return /^\d{10}$/.test(c) ? `+57 ${c.slice(0, 3)} ${c.slice(3, 6)} ${c.slice(6)}` : c;
}

function mostrarError(tipo) {
  const [titulo, detalle] = ERRORES[tipo];
  $('cargando').hidden = true;
  $('ficha').hidden = true;
  $('error').hidden = false;
  $('error-titulo').textContent = titulo;
  $('error-titulo').className = tipo === 'red' ? '' : 'error';
  $('error-detalle').textContent = detalle;
  $('reintentar').hidden = tipo !== 'red';
  document.title = `${titulo} · Rondó`;
}

function llenarEtiquetas(ul, lista) {
  ul.replaceChildren(...lista.map((t) => {
    const li = document.createElement('li');
    li.textContent = t;
    return li;
  }));
}

function mostrarFicha(f) {
  $('nombre').textContent = f.nombre || 'Sin nombre';
  document.title = `Ficha médica de ${f.nombre || 'una persona'} · Rondó`;

  const edad = edadDe(f.fechaNacimiento);
  if (edad) {
    $('edad').textContent = `${edad.edad} años · ${edad.texto}`;
    $('edad').hidden = false;
  }

  $('sangre').textContent = f.tipoSangre || '—';

  const alergias = textos(f.alergias);
  llenarEtiquetas($('alergias'), alergias);
  $('sin-alergias').hidden = alergias.length > 0;

  const enfermedades = textos(f.enfermedades);
  llenarEtiquetas($('enfermedades'), enfermedades);
  $('bloque-enfermedades').hidden = enfermedades.length === 0;

  const medicamentos = textos(f.medicamentos);
  llenarEtiquetas($('medicamentos'), medicamentos);
  $('bloque-medicamentos').hidden = medicamentos.length === 0;

  const notas = typeof f.notas === 'string' ? f.notas.trim() : '';
  $('notas').textContent = notas;
  $('bloque-notas').hidden = notas === '';

  const c = f.contacto;
  if (c && typeof c.celular === 'string' && /^\d{10}$/.test(c.celular)) {
    $('contacto-nombre').textContent = c.nombre || 'Contacto';
    $('contacto-detalle').textContent = [c.relacion, celularBonito(c.celular)].filter(Boolean).join(' · ');
    $('contacto-llamar').href = `tel:+57${c.celular}`;
    $('contacto-llamar').textContent = `Llamar a ${(c.nombre || 'su contacto').split(/\s+/)[0]}`;
    $('contacto').hidden = false;
    $('sin-contacto').hidden = true;
  } else {
    $('contacto').hidden = true;
    $('sin-contacto').hidden = false;
  }

  $('cargando').hidden = true;
  $('error').hidden = true;
  $('ficha').hidden = false;
}

/** RF-25: deja constancia de que la abrieron. Si falla, la ficha se ve igual. */
function registrarConsulta(token) {
  fetch(`${BASE}/fichas/${token}/consultas`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { en: { timestampValue: new Date().toISOString() } } }),
    keepalive: true,
  }).catch(() => {});
}

async function cargar() {
  const token = tokenDeLaUrl();
  if (!token) return mostrarError('invalido');

  $('error').hidden = true;
  $('cargando').hidden = false;

  let respuesta;
  try {
    respuesta = await fetch(`${BASE}/fichas/${token}`, { cache: 'no-store' });
  } catch {
    return mostrarError('red');
  }
  // 404: ese token nunca existió.
  if (respuesta.status === 404) return mostrarError('invalido');
  if (!respuesta.ok) return mostrarError('red');

  let ficha;
  try {
    ficha = campos((await respuesta.json()).fields || {});
  } catch {
    return mostrarError('red');
  }
  if (ficha.revocada === true) return mostrarError('revocado');

  mostrarFicha(ficha);
  registrarConsulta(token);
}

$('reintentar').addEventListener('click', cargar);
cargar();
