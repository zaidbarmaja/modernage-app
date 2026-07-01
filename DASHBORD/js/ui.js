// ===============================================================
//  عصر الحداثة — مساعدات بناء الواجهة (HTML) المشتركة بين الصفحات
// ===============================================================

import { escapeHtml } from "./utils.js";

// icon اختياري — إن كان فارغاً لا يُرسَم مربّع الأيقونة (تصميم نظيف بلا إيموجي).
export const kpi = (icon, value, label, variant = "") => `
  <div class="kpi ${variant ? "kpi--" + variant : ""}">
    ${icon ? `<div class="kpi__icon">${icon}</div>` : ""}
    <div>
      <div class="kpi__value num">${value}</div>
      <div class="kpi__label">${escapeHtml(label)}</div>
    </div>
  </div>`;

export const stat = (value, label) => `
  <div class="stat">
    <div class="stat__value num">${value}</div>
    <div class="stat__label">${escapeHtml(label)}</div>
  </div>`;

export const badge = (text, cls = "b-gray") =>
  `<span class="badge-s ${cls}">${escapeHtml(text)}</span>`;

export const card = (title, icon, bodyHtml, actionsHtml = "", bodyClass = "") => `
  <div class="card">
    <div class="card__head">
      ${icon ? `<span class="ico">${icon}</span>` : ""}<h3>${escapeHtml(title)}</h3>
      ${actionsHtml ? `<div class="actions">${actionsHtml}</div>` : ""}
    </div>
    <div class="card__body ${bodyClass}">${bodyHtml}</div>
  </div>`;

export const emptyState = (msg, icon = "📭") =>
  `<div class="empty">${icon ? `<span class="ico">${icon}</span>` : ""}${escapeHtml(msg)}</div>`;

export const loading = () => `<div class="loading">جارٍ التحميل…</div>`;

export const kv = (k, v, valClass = "") =>
  `<div class="kv"><span class="kv__k">${escapeHtml(k)}</span><span class="kv__v ${valClass}">${v}</span></div>`;

/** خيارات <option> من مصفوفة {value,label} أو [id,label]. */
export const options = (list, selected = "") =>
  list.map((o) => {
    const val = Array.isArray(o) ? o[0] : o.value;
    const lab = Array.isArray(o) ? o[1] : o.label;
    return `<option value="${escapeHtml(val)}"${String(val) === String(selected) ? " selected" : ""}>${escapeHtml(lab)}</option>`;
  }).join("");
