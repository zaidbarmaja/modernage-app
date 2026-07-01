// ===============================================================
//  صفحة: البصمة والحضور — سجلات حضور الموظفين + ملخّص + خرائط
//  الحسابات مطابقة لـ lib/models/attendance.dart.
// ===============================================================

import { store, onStore } from "../store.js";
import { card, stat, emptyState } from "../ui.js";
import {
  toDate, fmtDate, fmtTime, fmtDuration, fmtHours, dayKeyOf,
  deptLabel, mapsUrl, escapeHtml, openModal, toast, el,
} from "../utils.js";
import { updateAt, ts, COL } from "../data.js";

/** يحسب مقاييس سجل بصمة واحد (دقائق). */
export function attMetrics(r) {
  const ci = toDate(r.checkIn), co = toDate(r.checkOut);
  const startMin = r.workStartMin ?? 8 * 60;
  const endMin = r.workEndMin ?? 16 * 60;
  if (!ci) return { worked: 0, late: 0, early: 0, overtime: 0, change: 0, open: true };
  const day = new Date(ci.getFullYear(), ci.getMonth(), ci.getDate());
  const schedStart = new Date(day.getTime() + startMin * 60000);
  const schedEnd = new Date(day.getTime() + endMin * 60000);
  const mins = (a, b) => Math.round((a - b) / 60000);
  const late = Math.max(0, mins(ci, schedStart));
  if (!co) return { worked: 0, late, early: 0, overtime: 0, change: late, open: true };
  const worked = Math.max(0, mins(co, ci));
  const early = Math.max(0, mins(schedEnd, co));
  const overtime = Math.max(0, mins(co, schedEnd));
  return { worked, late, early, overtime, change: late + early, open: false };
}

let uidFilter = "";      // "" = الكل
let dateFilter = "";     // yyyy-mm-dd أو ""

/** Date → قيمة حقل datetime-local (بالتوقيت المحلّي: yyyy-MM-ddThh:mm). */
function toLocalInput(d) {
  d = toDate(d);
  if (!d) return "";
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** نافذة تعديل وقت الدخول/الخروج لسجل حضور واحد، وحفظه في Firestore. */
function openEditModal(r) {
  const ci = toDate(r.checkIn), co = toDate(r.checkOut);
  const form = el("form", { class: "form-grid", autocomplete: "off" });
  form.innerHTML = `
    <div class="field full">
      <label>👤 الموظف</label>
      <input type="text" value="${escapeHtml(r.userName || "موظف")}" readonly>
    </div>
    <div class="field full">
      <label>🟢 وقت الدخول</label>
      <input type="datetime-local" id="att-in" value="${toLocalInput(ci)}" required>
    </div>
    <div class="field full">
      <label>🔴 وقت الخروج <span class="hint">(اتركه فارغاً إذا كان الدوام ما زال مفتوحاً)</span></label>
      <input type="datetime-local" id="att-out" value="${toLocalInput(co)}">
    </div>`;

  openModal({
    title: "تعديل وقت الحضور",
    content: form,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (close) => close() },
      {
        label: "💾 حفظ التعديل",
        class: "btn--primary",
        onClick: async (close) => {
          const inVal = form.querySelector("#att-in").value;
          const outVal = form.querySelector("#att-out").value;
          if (!inVal) { toast("أدخل وقت الدخول أولاً", "error"); return; }
          const inDate = new Date(inVal);
          const outDate = outVal ? new Date(outVal) : null;
          if (Number.isNaN(inDate.getTime())) { toast("وقت الدخول غير صحيح", "error"); return; }
          if (outDate && outDate.getTime() < inDate.getTime()) {
            toast("وقت الخروج لا يمكن أن يكون قبل وقت الدخول", "error"); return;
          }
          try {
            await updateAt(COL.attendance, r.id, {
              checkIn: ts(inDate),
              checkOut: outDate ? ts(outDate) : null,
              dayKey: dayKeyOf(inDate),
            });
            toast("تم تحديث وقت الحضور بنجاح", "success");
            close();
          } catch (e) {
            toast("تعذّر الحفظ: " + (e?.message || e), "error");
          }
        },
      },
    ],
  });
}

function render(container) {
  const draw = () => {
    const all = store.data.attendance;

    // خريطة الموظفين الظاهرين في السجلات.
    const emp = new Map();
    for (const r of all) if (r.uid) emp.set(r.uid, r.userName || "موظف");
    if (uidFilter && !emp.has(uidFilter)) uidFilter = "";

    const filtered = all.filter((r) => {
      if (uidFilter && r.uid !== uidFilter) return false;
      if (dateFilter && r.dayKey !== dateFilter) return false;
      return true;
    });

    // الملخّص (الأيام المكتملة فقط).
    let days = 0, worked = 0, change = 0, overtime = 0;
    for (const r of filtered) {
      const m = attMetrics(r);
      if (m.open) continue;
      days++; worked += m.worked; change += m.change; overtime += m.overtime;
    }

    const empOptions = [...emp.entries()]
      .sort((a, b) => a[1].localeCompare(b[1], "ar"))
      .map(([id, name]) => `<option value="${escapeHtml(id)}"${id === uidFilter ? " selected" : ""}>${escapeHtml(name)}</option>`)
      .join("");

    const filters = `
      <div class="filters">
        <label class="f-field"><span>الموظف</span>
          <select id="att-emp"><option value="">كل الموظفين</option>${empOptions}</select>
        </label>
        <label class="f-field"><span>التاريخ</span>
          <input type="date" id="att-date" value="${dateFilter}">
        </label>
        <button class="btn btn--ghost btn--sm" id="att-clear">مسح الفلتر</button>
      </div>`;

    const summary = card("ملخّص الحضور", "📊", `
      <div class="stat-grid">
        ${stat(days, "أيام مكتملة")}
        ${stat(fmtHours(worked), "إجمالي ساعات العمل")}
        ${stat(fmtHours(overtime), "الساعات الإضافية")}
        ${stat(fmtHours(change), "التأخير/الانصراف المبكر")}
      </div>`);

    const rows = filtered.map((r) => {
      const m = attMetrics(r);
      const ci = toDate(r.checkIn), co = toDate(r.checkOut);
      const inMap = (r.checkInLat != null && r.checkInLng != null)
        ? `<a href="${mapsUrl(r.checkInLat, r.checkInLng)}" target="_blank" class="mini mini--view">📍 دخول</a>` : "";
      const outMap = (r.checkOutLat != null && r.checkOutLng != null)
        ? `<a href="${mapsUrl(r.checkOutLat, r.checkOutLng)}" target="_blank" class="mini mini--view">📍 خروج</a>` : "";
      return `<tr>
        <td>${escapeHtml(r.userName || "موظف")}<br><span class="badge-s b-olive">${escapeHtml(deptLabel(r.department))}</span></td>
        <td class="num">${fmtDate(ci)}</td>
        <td class="num">${fmtTime(ci)}</td>
        <td class="num">${co ? fmtTime(co) : '<span class="badge-s b-gold">مفتوح</span>'}</td>
        <td class="num">${co ? fmtDuration(m.worked) : "—"}</td>
        <td class="num">${m.overtime ? fmtDuration(m.overtime) : "—"}</td>
        <td class="num">${m.change ? fmtDuration(m.change) : "—"}</td>
        <td class="row-actions">
          <button class="mini mini--edit" data-edit="${escapeHtml(r.id)}">✎ تعديل الوقت</button>
          ${inMap}${outMap}
        </td>
      </tr>`;
    }).join("");

    const table = filtered.length ? `
      <div class="table-wrap">
        <table class="data">
          <thead><tr>
            <th>الموظف</th><th>التاريخ</th><th>الدخول</th><th>الخروج</th>
            <th>العمل</th><th>الإضافي</th><th>التأخير/المبكر</th><th>التعديل / الموقع</th>
          </tr></thead>
          <tbody>${rows}</tbody>
        </table>
      </div>` : emptyState("لا توجد سجلات حضور مطابقة.", "🗓️");

    container.innerHTML = `${filters}${summary}
      ${card(`السجلات (${filtered.length})`, "👆", table, "", "pad0")}`;

    // ربط الفلاتر
    container.querySelector("#att-emp").onchange = (e) => { uidFilter = e.target.value; draw(); };
    container.querySelector("#att-date").onchange = (e) => { dateFilter = e.target.value; draw(); };
    container.querySelector("#att-clear").onclick = () => { uidFilter = ""; dateFilter = ""; draw(); };

    // تعديل وقت الدخول/الخروج لأي سجل (متاح لكل من يفتح اللوحة)
    container.querySelectorAll("[data-edit]").forEach((b) => {
      b.onclick = () => {
        const rec = store.data.attendance.find((x) => x.id === b.dataset.edit);
        if (rec) openEditModal(rec);
      };
    });
  };

  draw();
  return onStore(draw);
}

export default {
  title: "البصمة والحضور",
  sub: "سجلات حضور الموظفين وملخّص الساعات",
  needs: ["attendance"],
  render,
};
