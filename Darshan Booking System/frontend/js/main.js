/* ── TTD main.js — shared across all pages ─────────────────
   Must be loaded BEFORE page-specific scripts               */

const API_BASE = 'http://localhost:5000/api';

// ── Token / Auth helpers ────────────────────────────────────
const getToken  = () => localStorage.getItem('ttd_token');
const getUser   = () => JSON.parse(localStorage.getItem('ttd_user') || 'null');
const isLoggedIn= () => !!getToken();

function saveAuth(token, user) {
  localStorage.setItem('ttd_token', token);
  localStorage.setItem('ttd_user', JSON.stringify(user));
}
function clearAuth() {
  localStorage.removeItem('ttd_token');
  localStorage.removeItem('ttd_user');
}
function logout() {
  clearAuth();
  window.location.href = 'login.html';
}
function requireLogin() {
  if (!isLoggedIn()) { window.location.href = 'login.html'; return false; }
  return true;
}

// ── API helper ──────────────────────────────────────────────
async function api(method, path, body) {
  const headers = { 'Content-Type': 'application/json' };
  const token   = getToken();
  if (token) headers['Authorization'] = 'Bearer ' + token;

  const res  = await fetch(API_BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const data = await res.json();

  if (res.status === 401 || res.status === 403) { clearAuth(); window.location.href = 'login.html'; }
  return data;
}

// ── Alert ────────────────────────────────────────────────────
function showAlert(id, msg, type = 'danger') {
  const el = document.getElementById(id);
  if (!el) return;
  el.innerHTML  = (type === 'success' ? '✅ ' : type === 'info' ? 'ℹ️ ' : '⚠️ ') + msg;
  el.className  = `alert alert-${type} show`;
  if (type !== 'info') setTimeout(() => { el.className = 'alert'; }, 6000);
}

// ── Button loading state ────────────────────────────────────
function btnLoading(btnId, loading, text) {
  const b = document.getElementById(btnId);
  if (!b) return;
  b.disabled = loading;
  const s = b.querySelector('.spin');
  const t = b.querySelector('.btn-text');
  if (s) s.style.display = loading ? 'block' : 'none';
  if (t && text) t.textContent = text;
}

// ── Format helpers ──────────────────────────────────────────
function fDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}
function fTime(t) {
  if (!t) return '—';
  const [h, m] = t.split(':');
  const hr = parseInt(h, 10);
  return `${hr > 12 ? hr - 12 : (hr === 0 ? 12 : hr)}:${m} ${hr >= 12 ? 'PM' : 'AM'}`;
}
function fMoney(n) {
  if (n == null) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
function badgeBs(status) {
  const map = { confirmed:'badge-confirmed', pending:'badge-pending', cancelled:'badge-cancelled', success:'badge-success', failed:'badge-failed' };
  return `<span class="badge ${map[status]||''}">${status}</span>`;
}

// ── Navbar ──────────────────────────────────────────────────
function initNav() {
  const user     = getUser();
  const loginLi  = document.getElementById('nl-login');
  const logoutLi = document.getElementById('nl-logout');
  const dashLi   = document.getElementById('nl-dash');
  const userName = document.getElementById('nl-username');

  if (user) {
    loginLi  && loginLi.classList.add('d-none');
    logoutLi && logoutLi.classList.remove('d-none');
    dashLi   && dashLi.classList.remove('d-none');
    if (userName) userName.textContent = user.name.split(' ')[0];
  } else {
    logoutLi && logoutLi.classList.add('d-none');
    dashLi   && dashLi.classList.add('d-none');
  }
  document.getElementById('nl-logout-btn')?.addEventListener('click', e => { e.preventDefault(); logout(); });

  // hamburger
  const ham   = document.getElementById('hamburger');
  const links = document.getElementById('navLinks');
  ham?.addEventListener('click', () => links?.classList.toggle('open'));

  // active link
  const page = location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav-links a').forEach(a => {
    if (a.getAttribute('href') === page) a.classList.add('active');
  });
}

document.addEventListener('DOMContentLoaded', initNav);
