// ===============================================================
//  صفحة: المالية — عقود المشاريع + الوصولات الإلكترونية + السلف والصرفيات
// ===============================================================

import { store, onStore } from "../store.js";
import { card, kpi, stat, emptyState, badge } from "../ui.js";
import { money, fmtDate, EXPENSE_TYPES, toDate, escapeHtml, toast } from "../utils.js";

let from = "", to = "";

/** مشاركة (صورة إن وُجدت كملف، وإلا نصّ + رابط) عبر واجهة مشاركة الجهاز / واتساب. */
async function shareImageOrText(imageUrl, title, text, idForFile) {
  // (1) الأفضل: مشاركة الصورة نفسها كملف (واتساب/تيليجرام…)
  if (imageUrl && navigator.canShare) {
    try {
      const blob = await (await fetch(imageUrl)).blob();
      const file = new File([blob], `receipt-${idForFile}.jpg`, { type: blob.type || "image/jpeg" });
      if (navigator.canShare({ files: [file] })) {
        await navigator.share({ files: [file], title, text });
        return;
      }
    } catch (e) {
      if (e?.name === "AbortError") return;   // ألغى المستخدم المشاركة
      // خلاف ذلك (CORS/عدم دعم) نتابع للبدائل التالية
    }
  }
  // (2) مشاركة نصّ + رابط الصورة عبر واجهة المشاركة القياسية
  const payload = imageUrl ? `${text}\n${imageUrl}` : text;
  if (navigator.share) {
    try { await navigator.share({ title, text: payload }); return; }
    catch (e) { if (e?.name === "AbortError") return; }
  }
  // (3) بديل: فتح واتساب بالنص جاهزاً
  window.open(`https://wa.me/?text=${encodeURIComponent(payload)}`, "_blank");
  toast("افتح واتساب لإتمام المشاركة", "info");
}

/** مشاركة وصل من مجموعة receipts (وصولات المشاريع/المواقع). */
function shareReceipt(r) {
  const kind = r.expense ? "صرف" : "قبض";
  const text = [
    `وصل ${kind}`,
    `التاريخ: ${fmtDate(r.date)}`,
    `الجهة: ${r.ownerName || "—"}${r.siteName ? " / " + r.siteName : ""}`,
    `المبلغ: ${money(r.amount)}`,
    r.description ? `الوصف: ${r.description}` : "",
    r.createdByName ? `المُصدِر: ${r.createdByName}` : "",
  ].filter(Boolean).join("\n");
  return shareImageOrText(r.imageUrl, `وصل ${kind}`, text, r.id);
}

/** مشاركة وصل إلكتروني من نظام الحسابات (customerTransactions/electronic) بصورته. */
function shareElecReceipt(t) {
  const isExpense = t.kind === "expense";
  const kind = isExpense ? "صرف" : "قبض";
  const amount = isExpense ? t.expense : t.receipt;
  const text = [
    `وصل ${kind} إلكتروني`,
    `التاريخ: ${fmtDate(t.datetime)}`,
    `الزبون: ${t.customerName || "—"}`,
    `المبلغ: ${money(amount)}`,
    t.description ? `الوصف: ${t.description}` : "",
  ].filter(Boolean).join("\n");
  return shareImageOrText(t.imageUrl, `وصل ${kind} إلكتروني`, text, t.id);
}

function inRange(d) {
  const t = toDate(d)?.getTime();
  if (t == null) return true;
  if (from && t < new Date(from + "T00:00:00").getTime()) return false;
  if (to && t > new Date(to + "T23:59:59").getTime()) return false;
  return true;
}

function render(container) {
  const draw = () => {
    const d = store.data;

    // عقود المشاريع
    let total = 0, paid = 0, remaining = 0, active = 0;
    for (const p of d.projects) {
      total += Number(p.totalAmount) || 0;
      paid += Number(p.paidAmount) || 0;
      const rem = Math.max(0, (Number(p.totalAmount) || 0) - (Number(p.paidAmount) || 0));
      remaining += rem; if (rem > 0) active++;
    }

    const receipts = d.receipts.filter((r) => inRange(r.date));
    let recIn = 0, recOut = 0;
    for (const r of receipts) (r.expense ? (recOut += Number(r.amount) || 0) : (recIn += Number(r.amount) || 0));

    const expenses = d.expenses.filter((e) => inRange(e.date));
    let adv = 0, spend = 0;
    for (const e of expenses) (e.type === "advance" ? (adv += Number(e.amount) || 0) : (spend += Number(e.amount) || 0));

    const contracts = `
      <div class="kpi-grid">
        ${kpi("📋", active, "مشاريع نشطة", "gold")}
        ${kpi("📄", money(total), "إجمالي العقود", "")}
        ${kpi("✅", money(paid), "المحصّل", "green")}
        ${kpi("⏳", money(remaining), "المتبقّي", "red")}
      </div>`;

    const filters = `
      <div class="filters">
        <label class="f-field"><span>من تاريخ</span><input type="date" id="fin-from" value="${from}"></label>
        <label class="f-field"><span>إلى تاريخ</span><input type="date" id="fin-to" value="${to}"></label>
        <button class="btn btn--ghost btn--sm" id="fin-clear">مسح</button>
      </div>`;

    // جدول الوصولات
    const recRows = receipts.slice(0, 200).map((r) => `
      <tr>
        <td class="num">${fmtDate(r.date)}</td>
        <td>${escapeHtml(r.ownerName || "—")}<br><span class="muted">${escapeHtml(r.siteName || "")}</span></td>
        <td>${r.expense ? badge("صرف", "b-red") : badge("قبض", "b-green")}</td>
        <td class="num ${r.expense ? "neg" : "pos"}">${money(r.amount)}</td>
        <td>${escapeHtml(r.description || "—")}</td>
        <td>${escapeHtml(r.createdByName || "—")}</td>
        <td class="row-actions">
          ${r.imageUrl ? `<a class="mini mini--view" href="${escapeHtml(r.imageUrl)}" target="_blank">📎 صورة</a>` : ""}
          <button class="mini mini--ok" data-share="${escapeHtml(r.id)}">مشاركة</button>
        </td>
      </tr>`).join("");

    const recTable = receipts.length ? `
      <div class="table-wrap"><table class="data">
        <thead><tr><th>التاريخ</th><th>صاحب المشروع/الموقع</th><th>النوع</th><th>المبلغ</th><th>الوصف</th><th>المُصدِر</th><th>المرفق / مشاركة</th></tr></thead>
        <tbody>${recRows}</tbody>
      </table></div>` : emptyState("لا توجد وصولات مطابقة", "🧾");

    // جدول الصرفيات
    const expRows = expenses.slice(0, 200).map((e) => `
      <tr>
        <td class="num">${fmtDate(e.date)}</td>
        <td>${escapeHtml(e.siteName || "—")}<br><span class="muted">${escapeHtml(e.ownerName || "")}</span></td>
        <td>${e.type === "advance" ? badge("سلفة", "b-gold") : badge("صرفية", "b-blue")}</td>
        <td class="num neg">${money(e.amount)}</td>
        <td>${escapeHtml(e.note || "—")}</td>
        <td>${escapeHtml(e.executorName || "—")}</td>
      </tr>`).join("");

    const expTable = expenses.length ? `
      <div class="table-wrap"><table class="data">
        <thead><tr><th>التاريخ</th><th>الموقع</th><th>النوع</th><th>المبلغ</th><th>الملاحظة</th><th>المنفّذ</th></tr></thead>
        <tbody>${expRows}</tbody>
      </table></div>` : emptyState("لا توجد سلف/صرفيات مطابقة", "💵");

    // الوصولات الإلكترونية القادمة من نظام الحسابات (بصورها) — لحظية،
    // وتختفي تلقائياً عند حذفها من الحسابات (نُخفي المحذوف soft-deleted).
    const elecTx = (d.electronicReceipts || [])
      .filter((t) => t.deleted !== true && inRange(t.datetime));
    let eIn = 0, eOut = 0;
    for (const t of elecTx) (t.kind === "expense" ? (eOut += Number(t.expense) || 0) : (eIn += Number(t.receipt) || 0));

    const elecRows = elecTx.slice(0, 200).map((t) => {
      const isExpense = t.kind === "expense";
      const amount = isExpense ? t.expense : t.receipt;
      return `<tr>
        <td class="num">${fmtDate(t.datetime)}</td>
        <td>${escapeHtml(t.customerName || "—")}</td>
        <td>${isExpense ? badge("صرف", "b-red") : badge("قبض", "b-green")}</td>
        <td class="num ${isExpense ? "neg" : "pos"}">${money(amount)}</td>
        <td>${escapeHtml(t.description || "—")}</td>
        <td>${t.imageUrl ? `<a href="${escapeHtml(t.imageUrl)}" target="_blank" title="عرض الصورة كاملة"><img src="${escapeHtml(t.imageUrl)}" class="receipt-thumb" alt="صورة الوصل" loading="lazy"></a>` : '<span class="muted">—</span>'}</td>
        <td class="row-actions"><button class="mini mini--ok" data-share-tx="${escapeHtml(t.id)}">مشاركة</button></td>
      </tr>`;
    }).join("");

    const elecTable = elecTx.length ? `
      <div class="table-wrap"><table class="data">
        <thead><tr><th>التاريخ</th><th>الزبون</th><th>النوع</th><th>المبلغ</th><th>الوصف</th><th>الصورة</th><th>مشاركة</th></tr></thead>
        <tbody>${elecRows}</tbody>
      </table></div>` : emptyState("لا توجد وصولات إلكترونية من الحسابات", "🧾");

    container.innerHTML = `
      ${card("عقود المشاريع", "📊", contracts, "", "pad0")}
      ${filters}
      ${card("الوصولات الإلكترونية (من الحسابات)", "🧾", `
        <div class="stat-grid" style="margin-bottom:14px">
          ${stat(elecTx.length, "عدد الوصولات")}
          ${stat(money(eIn), "إجمالي القبض")}
          ${stat(money(eOut), "إجمالي الصرف")}
        </div>${elecTable}`)}
      ${card("وصولات المشاريع والمواقع (المدفوعات)", "🧾", `
        <div class="stat-grid" style="margin-bottom:14px">
          ${stat(receipts.length, "عدد الوصولات")}
          ${stat(money(recIn), "إجمالي المقبوض")}
          ${stat(money(recOut), "إجمالي المصروف")}
        </div>${recTable}`)}
      ${card("السلف والصرفيات", "💵", `
        <div class="stat-grid" style="margin-bottom:14px">
          ${stat(money(adv), "إجمالي السلف")}
          ${stat(money(spend), "إجمالي الصرفيات")}
          ${stat(expenses.length, "عدد الحركات")}
        </div>${expTable}`)}`;

    container.querySelector("#fin-from").onchange = (e) => { from = e.target.value; draw(); };
    container.querySelector("#fin-to").onchange = (e) => { to = e.target.value; draw(); };
    container.querySelector("#fin-clear").onclick = () => { from = ""; to = ""; draw(); };

    // زر مشاركة وصل من وصولات المشاريع (receipts)
    container.querySelectorAll("[data-share]").forEach((b) => {
      b.onclick = () => {
        const r = store.data.receipts.find((x) => x.id === b.dataset.share);
        if (r) shareReceipt(r);
      };
    });
    // زر مشاركة وصل إلكتروني من الحسابات (بصورته)
    container.querySelectorAll("[data-share-tx]").forEach((b) => {
      b.onclick = () => {
        const t = (store.data.electronicReceipts || []).find((x) => x.id === b.dataset.shareTx);
        if (t) shareElecReceipt(t);
      };
    });
  };

  draw();
  return onStore(draw);
}

export default {
  title: "المالية",
  sub: "العقود والوصولات والسلف والصرفيات",
  needs: ["receipts", "expenses", "electronicReceipts", "projects"],
  render,
};
