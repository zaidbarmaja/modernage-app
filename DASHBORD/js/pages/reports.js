// ===============================================================
//  صفحة: التقارير — التقارير اليومية للموظفين + تقارير التنفيذ (بالصور)
// ===============================================================

import { store, onStore } from "../store.js";
import { card, emptyState, badge, kv } from "../ui.js";
import { fmtDate, fmtDateTime, toDate, dayKeyOf, openModal, escapeHtml } from "../utils.js";

/** نافذة تفاصيل التقرير اليومي — تعرض النصّ كاملاً كما كتبه الموظف. */
function dailyReportModal(r) {
  const content = (r.content || "").trim();
  openModal({
    title: "تفاصيل التقرير اليومي",
    wide: true,
    content: `
      <div class="rep-detail">
        ${kv("الموظف", escapeHtml(r.userName || "موظف"))}
        ${kv("التاريخ", fmtDate(r.date))}
        ${kv("المشروع", r.projectName ? escapeHtml(r.projectName) : "—")}
        ${kv("وقت الإرسال", fmtDateTime(r.createdAt))}
        <div style="margin-top:14px;padding-top:14px;border-top:1px solid var(--border)">
          <div style="font-weight:700;margin-bottom:8px">نصّ التقرير</div>
          <div style="white-space:pre-wrap;line-height:1.9">${content ? escapeHtml(content) : "لا يوجد نصّ في هذا التقرير."}</div>
        </div>
      </div>`,
  });
}

let tab = "daily";      // daily | execution
let empFilter = "";
let period = "all";     // all | today | yesterday | week | month
let siteFilter = "";

function inPeriod(d) {
  const date = toDate(d);
  if (!date) return false;
  if (period === "all") return true;
  const now = new Date();
  const key = dayKeyOf(date);
  if (period === "today") return key === dayKeyOf(now);
  if (period === "yesterday") {
    const y = new Date(now); y.setDate(now.getDate() - 1);
    return key === dayKeyOf(y);
  }
  if (period === "week") {
    const w = new Date(now); w.setDate(now.getDate() - 7);
    return date >= w;
  }
  if (period === "month") return date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth();
  return true;
}

const periodChips = () => `
  <div class="chips">
    ${[["all", "الكل"], ["today", "اليوم"], ["yesterday", "أمس"], ["week", "آخر أسبوع"], ["month", "هذا الشهر"]]
      .map(([v, l]) => `<button class="chip ${period === v ? "active" : ""}" data-period="${v}">${l}</button>`).join("")}
  </div>`;

function photosModal(urls) {
  openModal({
    title: "صور التقرير",
    wide: true,
    content: `<div class="photo-grid">${urls.map((u) =>
      `<a href="${escapeHtml(u)}" target="_blank"><img src="${escapeHtml(u)}"></a>`).join("")}</div>`,
  });
}

function render(container) {
  const draw = () => {
    const d = store.data;

    // خيارات الموظفين حسب التبويب
    const nameSet = new Map();
    (tab === "daily" ? d.dailyReports : d.executionReports).forEach((r) => {
      const id = tab === "daily" ? r.uid : r.executorUid;
      const nm = tab === "daily" ? r.userName : r.executorName;
      if (id) nameSet.set(id, nm || "موظف");
    });
    if (empFilter && !nameSet.has(empFilter)) empFilter = "";

    const empOpts = [...nameSet.entries()].sort((a, b) => a[1].localeCompare(b[1], "ar"))
      .map(([id, nm]) => `<option value="${escapeHtml(id)}"${id === empFilter ? " selected" : ""}>${escapeHtml(nm)}</option>`).join("");

    const seg = `
      <div class="chips" style="margin-bottom:14px">
        <button class="chip ${tab === "daily" ? "active" : ""}" data-tab="daily">📝 التقارير اليومية</button>
        <button class="chip ${tab === "execution" ? "active" : ""}" data-tab="execution">🏗️ تقارير التنفيذ</button>
      </div>`;

    const filters = `
      <div class="filters">
        <label class="f-field"><span>${tab === "daily" ? "الموظف" : "المنفّذ"}</span>
          <select id="rep-emp"><option value="">الكل</option>${empOpts}</select>
        </label>
        <div class="f-field"><span>الفترة</span>${periodChips()}</div>
      </div>`;

    let body;
    if (tab === "daily") {
      const rows = d.dailyReports
        .filter((r) => (!empFilter || r.uid === empFilter) && inPeriod(r.date))
        .slice(0, 300);
      const snippet = (t) => {
        const s = (t || "").replace(/\s+/g, " ").trim();
        return s.length > 90 ? escapeHtml(s.slice(0, 90)) + "…" : (s ? escapeHtml(s) : "—");
      };
      body = rows.length ? `
        <div class="table-wrap"><table class="data">
          <thead><tr><th>التاريخ</th><th>الموظف</th><th>المشروع</th><th>المحتوى</th><th></th></tr></thead>
          <tbody>${rows.map((r, i) => `<tr class="clickable-row" data-report="${i}" title="اضغط لعرض التقرير كاملاً">
            <td class="num">${fmtDate(r.date)}</td>
            <td>${escapeHtml(r.userName || "موظف")}</td>
            <td>${r.projectName ? badge(r.projectName, "b-olive") : "—"}</td>
            <td>${snippet(r.content)}</td>
            <td><span class="mini mini--view">عرض ↗</span></td>
          </tr>`).join("")}</tbody>
        </table></div>` : emptyState("لا توجد تقارير مطابقة", "📝");
      body = card(`التقارير اليومية (${rows.length})`, "📝", body, "", "pad0");
      // خزّن الصفوف للوصول من النقر لعرض التفاصيل.
      render._dailyRows = rows;
    } else {
      const rows = d.executionReports
        .filter((r) => (!empFilter || r.executorUid === empFilter) && inPeriod(r.date))
        .slice(0, 200);
      body = rows.length ? `<div class="cards-grid">${rows.map((r, i) => {
        const photos = (r.photoUrls || []).length;
        return `<div class="item-card">
          <div class="item-card__head">
            <div>
              <div class="item-card__title">${escapeHtml(r.siteName || "موقع")}</div>
              <div class="item-card__sub">${escapeHtml(r.ownerName || "")} • ${fmtDate(r.date)}</div>
            </div>
            <span class="spacer"></span>${badge(r.executorName || "منفّذ", "b-blue")}
          </div>
          ${r.documentsNotes ? `<div>${escapeHtml(r.documentsNotes)}</div>` : ""}
          ${r.plannedNextDays ? `<div class="item-card__sub">📅 القادم: ${escapeHtml(r.plannedNextDays)}</div>` : ""}
          <div class="item-card__foot">
            ${r.durationDays ? badge("المدة: " + r.durationDays + " يوم", "b-gray") : ""}
            ${photos ? `<button class="mini mini--view" data-photos="${i}">🖼️ ${photos} صور</button>` : `<span class="muted">لا صور</span>`}
          </div>
        </div>`;
      }).join("")}</div>` : emptyState("لا توجد تقارير تنفيذ مطابقة", "🏗️");
      body = card(`تقارير التنفيذ (${rows.length})`, "🏗️", body);
      // خزّن للوصول من زر الصور
      render._execRows = rows;
    }

    container.innerHTML = `${seg}${filters}${body}`;

    container.querySelectorAll("[data-tab]").forEach((b) =>
      b.onclick = () => { tab = b.dataset.tab; empFilter = ""; draw(); });
    container.querySelectorAll("[data-period]").forEach((b) =>
      b.onclick = () => { period = b.dataset.period; draw(); });
    const emp = container.querySelector("#rep-emp");
    if (emp) emp.onchange = (e) => { empFilter = e.target.value; draw(); };
    container.querySelectorAll("[data-photos]").forEach((b) =>
      b.onclick = () => photosModal(render._execRows[+b.dataset.photos].photoUrls || []));
    // نقر صفّ التقرير اليومي → عرض التقرير كاملاً.
    container.querySelectorAll("[data-report]").forEach((tr) =>
      tr.onclick = () => dailyReportModal(render._dailyRows[+tr.dataset.report]));
  };

  draw();
  return onStore(draw);
}

export default {
  title: "التقارير",
  sub: "التقارير اليومية وتقارير التنفيذ",
  needs: ["dailyReports", "executionReports"],
  render,
};
