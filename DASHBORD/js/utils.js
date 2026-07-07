// ===============================================================
//  عصر الحداثة — أدوات مساعدة موحّدة للوحة التحكم
//  تنسيق التواريخ/المبالغ/الساعات · التسميات العربية · التنبيهات
//  والنوافذ · تجزئة كلمات المرور (مطابقة تماماً لـ lib/services/auth_service.dart)
// ===============================================================

/* ----------------------------- تنسيق ----------------------------- */

const _money = new Intl.NumberFormat("en-US", { maximumFractionDigits: 0 });

export function money(v, currency = "د.ع") {
  if (v === null || v === undefined || v === "") return "—";
  return `${_money.format(Number(v) || 0)} ${currency}`;
}

const _pad = (n) => String(n).padStart(2, "0");

/** yyyy/MM/dd — مطابق لـ Fmt.date في التطبيق. */
export function fmtDate(d) {
  d = toDate(d);
  if (!d) return "—";
  return `${d.getFullYear()}/${_pad(d.getMonth() + 1)}/${_pad(d.getDate())}`;
}

/** hh:mm a (12 ساعة) — مطابق لـ Fmt.time. */
export function fmtTime(d) {
  d = toDate(d);
  if (!d) return "—";
  let h = d.getHours();
  const m = _pad(d.getMinutes());
  const ap = h >= 12 ? "PM" : "AM";
  h = h % 12 || 12;
  return `${_pad(h)}:${m} ${ap}`;
}

export function fmtDateTime(d) {
  d = toDate(d);
  if (!d) return "—";
  return `${fmtDate(d)}  ${fmtTime(d)}`;
}

/** عدد دقائق → "س ساعة و د دقيقة" — مطابق لـ Fmt.duration. */
export function fmtDuration(minutes) {
  minutes = Math.round(minutes || 0);
  if (minutes <= 0) return "0 دقيقة";
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m} دقيقة`;
  if (m === 0) return `${h} ساعة`;
  return `${h} ساعة و ${m} دقيقة`;
}

/** ساعات عشرية — مطابق لـ Fmt.hours (مثلاً 7.5 ساعة). */
export function fmtHours(minutes) {
  return `${((minutes || 0) / 60).toFixed(1)} ساعة`;
}

/** دقائق من منتصف الليل → HH:MM (24 ساعة) لعرض/تحرير أوقات الدوام. */
export function minToHHMM(min) {
  if (min === null || min === undefined) return "";
  const h = Math.floor(min / 60);
  const m = min % 60;
  return `${_pad(h)}:${_pad(m)}`;
}

/** HH:MM → دقائق من منتصف الليل. */
export function hhmmToMin(str) {
  if (!str) return null;
  const [h, m] = String(str).split(":").map((x) => parseInt(x, 10));
  if (Number.isNaN(h) || Number.isNaN(m)) return null;
  return h * 60 + m;
}

/** مفتاح اليوم yyyy-MM-dd — مطابق لـ dayKeyOf في التطبيق. */
export function dayKeyOf(d) {
  d = toDate(d) || new Date();
  return `${d.getFullYear()}-${_pad(d.getMonth() + 1)}-${_pad(d.getDate())}`;
}

/** تحويل Timestamp/Date/ISO إلى Date (أو null). */
export function toDate(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  if (typeof v.toDate === "function") return v.toDate(); // Firestore Timestamp
  if (typeof v === "object" && typeof v.seconds === "number") {
    return new Date(v.seconds * 1000);
  }
  if (typeof v === "string") {
    const d = new Date(v);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof v === "number") return new Date(v);
  return null;
}

/* --------------------------- التسميات --------------------------- */

export const ROLES = {
  admin: { label: "الإدارة", icon: "🛡️" },
  accounting: { label: "المحاسبة", icon: "🧮" },
  designEmployee: { label: "موظف التصميم", icon: "📐" },
  executionEmployee: { label: "موظف التنفيذ", icon: "👷" },
  customer: { label: "الزبون", icon: "🙍" },
};
export const roleLabel = (id) => ROLES[id]?.label || "الزبون";

export const DEPARTMENTS = {
  civil: { label: "المدني", schedule: "7 ص - 3 م" },
  architectural: { label: "المعماري", schedule: "10 ص - 6 م" },
  none: { label: "بدون قسم", schedule: "لا يوجد" },
};
export const deptLabel = (id) => DEPARTMENTS[id]?.label || "بدون قسم";

export const WORK_CATEGORIES = {
  general: "تنفيذ عام",
  poolsSupervision: "إشراف مسابح",
  poolsExecution: "تنفيذ مسابح",
};
export const categoryLabel = (id) => WORK_CATEGORIES[id] || "تنفيذ عام";

export const EXPENSE_TYPES = { advance: "سلفة", spending: "صرفية" };

export const OFFER_TYPES = [
  "تصميم معماري", "تصميم داخلي", "إشراف هندسي",
  "تصميم وتنفيذ", "استشارة هندسية", "أخرى",
];

export const PROJECT_STATUSES = ["قيد العمل", "منجز", "معلّق"];

/* -------- الفئات المستهدفة للإشعارات/التنبيهات (توجيه حسب الفئة) -------- */

export const AUDIENCES = [
  ["all", "الجميع"],
  ["execution", "موظفو التنفيذ"],
  ["design", "موظفو التصميم"],
  ["pools", "موظفو المسابح"],
  ["customers", "الزبائن"],
];

export const audienceLabel = (a) =>
  (AUDIENCES.find((x) => x[0] === a) || ["", "الجميع"])[1];

/** هل يطابق المستخدم [u] الفئة المستهدفة [audience]؟ (مطابق لـ ScheduledReminder.matchesUser في التطبيق) */
export function audienceMatches(audience, u) {
  if (!audience || audience === "all") return true;
  const role = u.role;
  const cat = u.workCategory;
  switch (audience) {
    case "execution":
      return role === "executionEmployee";
    case "design":
      return role === "designEmployee";
    case "pools":
      return role === "executionEmployee" &&
        (cat === "poolsSupervision" || cat === "poolsExecution");
    case "customers":
      return role === "customer";
    default:
      return true;
  }
}

/* ----------------------- مساعدات DOM/HTML ----------------------- */

export function escapeHtml(str) {
  return String(str ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

/** إنشاء عنصر بسرعة: el('div', {class:'x'}, 'نص' | [عناصر]). */
export function el(tag, attrs = {}, children = null) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === null || v === undefined || v === false) continue;
    if (k === "class") node.className = v;
    else if (k === "html") node.innerHTML = v;
    else if (k === "text") node.textContent = v;
    else if (k.startsWith("on") && typeof v === "function") {
      node.addEventListener(k.slice(2).toLowerCase(), v);
    } else node.setAttribute(k, v);
  }
  if (children != null) {
    for (const c of Array.isArray(children) ? children : [children]) {
      if (c == null) continue;
      node.append(c.nodeType ? c : document.createTextNode(String(c)));
    }
  }
  return node;
}

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

/* --------------------------- التنبيهات --------------------------- */

export function toast(message, type = "info", ms = 2600) {
  const box = $("#toast-container") || document.body;
  const t = el("div", { class: `toast toast--${type}`, text: message });
  box.appendChild(t);
  requestAnimationFrame(() => t.classList.add("toast--show"));
  setTimeout(() => {
    t.classList.remove("toast--show");
    setTimeout(() => t.remove(), 320);
  }, ms);
}

/* ---------------------------- النوافذ ---------------------------- */

/**
 * نافذة عامة. content يمكن أن يكون نصاً HTML أو عنصر DOM.
 * تُرجع { overlay, close } للتحكّم. actions: [{label, class, onClick(close)}].
 */
export function openModal({ title = "", content = "", wide = false, actions = [], onClose = null } = {}) {
  const root = $("#modal-root") || document.body;
  const overlay = el("div", { class: "modal-overlay" });
  const modal = el("div", { class: `modal${wide ? " modal--wide" : ""}`, role: "dialog" });
  let closed = false;
  const close = () => {
    if (closed) return;
    closed = true;
    overlay.remove();
    document.removeEventListener("keydown", onKey);
    onClose?.();
  };
  function onKey(e) { if (e.key === "Escape") close(); }
  document.addEventListener("keydown", onKey);

  modal.appendChild(el("button", { class: "modal__close", text: "×", onClick: close }));
  if (title) modal.appendChild(el("h3", { class: "modal__title", text: title }));

  const body = el("div", { class: "modal__content" });
  if (typeof content === "string") body.innerHTML = content;
  else body.appendChild(content);
  modal.appendChild(body);

  if (actions.length) {
    const bar = el("div", { class: "modal__actions" });
    for (const a of actions) {
      bar.appendChild(el("button", {
        class: `btn ${a.class || "btn--ghost"}`,
        text: a.label,
        onClick: () => a.onClick?.(close),
      }));
    }
    modal.appendChild(bar);
  }

  overlay.appendChild(modal);
  overlay.addEventListener("click", (e) => { if (e.target === overlay) close(); });
  root.appendChild(overlay);
  return { overlay, modal, body, close };
}

/** تأكيد بسيط (نعم/لا). تُرجع Promise<boolean>. */
export function confirmDialog(message, { title = "تأكيد", okText = "تأكيد", danger = true } = {}) {
  return new Promise((resolve) => {
    let done = false;
    const finish = (val) => { if (!done) { done = true; resolve(val); } };
    openModal({
      title,
      content: `<p class="modal__body">${escapeHtml(message)}</p>`,
      onClose: () => finish(false), // إغلاق بالخلفية/Escape = إلغاء
      actions: [
        { label: "إلغاء", class: "btn--ghost", onClick: (c) => { finish(false); c(); } },
        { label: okText, class: danger ? "btn--danger" : "btn--primary", onClick: (c) => { finish(true); c(); } },
      ],
    });
  });
}

/* --------------- تطبيع الدخول وتجزئة كلمة المرور --------------- */
//  مطابق تماماً لـ AuthService في التطبيق حتى تعمل الحسابات المُنشأة من اللوحة
//  في تطبيق الجوال والعكس.

/** تطبيع مُعرّف الدخول (اسم/هاتف). */
export function normId(id) {
  return String(id).trim().toLowerCase().replace(/\s+/g, " ");
}

/** مفاتيح الدخول المطبّعة (الاسم + الهاتف إن وُجد). */
export function loginKeys(loginId, phone = "") {
  const keys = new Set([normId(loginId)]);
  if (String(phone).trim()) keys.add(normId(phone));
  return [...keys];
}

/** يحوّل مُعرّف الدخول إلى بريد مصادقة داخلي ثابت — مطابق لـ _idToEmail. */
export function idToEmail(id) {
  const norm = normId(id);
  let h = 0;
  for (let i = 0; i < norm.length; i++) {
    h = (h * 31 + norm.charCodeAt(i)) % 1000000007;
  }
  return `u${h}@modernage.local`;
}

const _PW_SALT = "modernage::pw::v1";
const _PW_ITER = 12000;
const _enc = new TextEncoder();
const _toHex = (bytes) => Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");

async function _sha256(bytes) {
  const buf = await crypto.subtle.digest("SHA-256", bytes);
  return new Uint8Array(buf);
}

/** التمطيط (key stretching) — مطابق لـ AuthService._stretch. */
async function _stretch(salt, uid, plain) {
  let digest = await _sha256(_enc.encode(`${_PW_SALT}|${salt}|${uid}|${plain}`));
  for (let i = 1; i < _PW_ITER; i++) digest = await _sha256(digest);
  return _toHex(digest);
}

/** ملح عشوائي (16 بايت hex) — مطابق لـ AuthService.newSalt. */
export function newSalt() {
  const b = new Uint8Array(16);
  crypto.getRandomValues(b);
  return _toHex(b);
}

/** ينشئ اعتماد {salt, hash} لكلمة مرور — مطابق لـ makeCredential. */
export async function makeCredential(uid, plain) {
  const salt = newSalt();
  const hash = await _stretch(salt, uid, String(plain).trim());
  return { salt, hash };
}

/** رمز وصول رقمي (٤ خانات) لحساب الزبون. */
export function generateAccessCode() {
  return Array.from({ length: 4 }, () => Math.floor(Math.random() * 10)).join("");
}

/** رابط خرائط جوجل لإحداثيات. */
export function mapsUrl(lat, lng) {
  return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
}
