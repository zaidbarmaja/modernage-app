// ===============================================================
//  صفحة: نظرة عامة — ملخّص شامل لكل النظام
// ===============================================================

import { store, onStore, employees, customers } from "../store.js";
import { kpi, card, emptyState } from "../ui.js";
import { money, fmtDate, fmtDateTime, dayKeyOf, escapeHtml } from "../utils.js";

function render(container) {
  const draw = () => {
    const d = store.data;
    const today = dayKeyOf(new Date());

    let total = 0, paid = 0, remaining = 0, active = 0;
    for (const p of d.projects) {
      total += Number(p.totalAmount) || 0;
      paid += Number(p.paidAmount) || 0;
      const rem = Math.max(0, (Number(p.totalAmount) || 0) - (Number(p.paidAmount) || 0));
      remaining += rem;
      if (rem > 0) active++;
    }
    const presentToday = new Set(
      d.attendance.filter((a) => a.dayKey === today).map((a) => a.uid)
    ).size;
    const receiptsTotal = d.receipts.reduce((s, r) => s + (Number(r.amount) || 0), 0);

    const kpis = `
      <div class="kpi-grid">
        ${kpi("", d.projects.length, "مشاريع التصميم", "")}
        ${kpi("", d.sites.length, "مواقع التنفيذ", "blue")}
        ${kpi("", employees().length, "الموظفون", "gold")}
        ${kpi("", customers().length, "الزبائن", "")}
        ${kpi("", presentToday, "حاضرون اليوم", "green")}
        ${kpi("", active, "مشاريع نشطة (متبقٍّ عليها دفعات)", "gold")}
      </div>
      <div class="kpi-grid">
        ${kpi("", money(total), "إجمالي العقود", "")}
        ${kpi("", money(paid), "المحصّل", "green")}
        ${kpi("", money(remaining), "المتبقّي", "red")}
        ${kpi("", money(receiptsTotal), "إجمالي المدفوعات (الوصولات)", "blue")}
      </div>`;

    // أحدث النشاطات
    const recentReports = d.dailyReports.slice(0, 6).map((r) => `
      <div class="kv"><span class="kv__k">${escapeHtml(r.userName || "موظف")} — ${fmtDate(r.date)}</span>
      <span class="kv__v">${escapeHtml((r.content || "").slice(0, 40))}${(r.content || "").length > 40 ? "…" : ""}</span></div>`).join("")
      || emptyState("لا توجد تقارير بعد", "");

    const recentReceipts = d.receipts.slice(0, 6).map((r) => `
      <div class="kv"><span class="kv__k">${escapeHtml(r.ownerName || r.siteName || "—")} — ${fmtDate(r.date)}</span>
      <span class="kv__v ${r.expense ? "neg" : "pos"}">${money(r.amount)}</span></div>`).join("")
      || emptyState("لا توجد مدفوعات بعد", "");

    const recentCheckins = d.siteCheckins.slice(0, 6).map((c) => `
      <div class="kv"><span class="kv__k">${escapeHtml(c.executorName || "منفّذ")} — ${escapeHtml(c.siteName || "")}</span>
      <span class="kv__v">${fmtDateTime(c.time)}</span></div>`).join("")
      || emptyState("لا تسجيلات مواقع بعد", "");

    container.innerHTML = `
      ${kpis}
      <div class="grid-3">
        ${card("أحدث التقارير اليومية", "", `<div class="kv-list">${recentReports}</div>`)}
        ${card("أحدث المدفوعات", "", `<div class="kv-list">${recentReceipts}</div>`)}
        ${card("أحدث تسجيلات المواقع", "", `<div class="kv-list">${recentCheckins}</div>`)}
      </div>`;
  };

  draw();
  return onStore(draw);
}

export default {
  title: "نظرة عامة",
  sub: "ملخّص شامل لكل النظام",
  needs: ["projects", "sites", "users", "attendance", "receipts", "dailyReports", "siteCheckins"],
  render,
};
