// ===============================================================
//  صفحة: المشاريع والمواقع — مشاريع التصميم (projects) ومواقع التنفيذ (sites)
//  إضافة/تعديل/حذف + تفاصيل (المهام، الملاحظات، التقارير، الوصولات).
// ===============================================================

import { store, onStore, designers, executors, accountCustomers } from "../store.js";
import {
  addTo, updateAt, ts, deleteProjectCascade, deleteSiteCascade, COL,
} from "../data.js";
import { card, badge, emptyState, options, kv } from "../ui.js";
import {
  money, fmtDate, fmtDateTime, toDate, OFFER_TYPES, PROJECT_STATUSES,
  WORK_CATEGORIES, categoryLabel, openModal, confirmDialog, toast, escapeHtml,
} from "../utils.js";

let search = "", typeFilter = "all", statusFilter = "", custFilter = "", catFilter = "";

/* ------------------------ حسابات مساعدة ------------------------ */

function projectProgress(p) {
  const tasks = p.tasks || [];
  if (!tasks.length) return null;
  const totalDays = tasks.reduce((s, t) => s + (Number(t.days) || 0), 0);
  if (totalDays > 0) {
    const doneDays = tasks.filter((t) => t.done).reduce((s, t) => s + (Number(t.days) || 0), 0);
    return Math.round((doneDays / totalDays) * 100);
  }
  return Math.round((tasks.filter((t) => t.done).length / tasks.length) * 100);
}
const remainingAmount = (p) => Math.max(0, (Number(p.totalAmount) || 0) - (Number(p.paidAmount) || 0));

function siteProgress(s) {
  const d = Number(s.durationDays);
  const created = toDate(s.createdAt);
  if (!d || d <= 0 || !created) return null;
  const elapsed = Math.floor((Date.now() - created.getTime()) / 86400000);
  if (elapsed <= 0) return 0;
  return Math.min(100, Math.round((elapsed / d) * 100));
}

// زبائن نظام الحسابات الأصلي (تُجلب من Firebase) — لربط المشروع بزبون موجود مسبقاً.
const custOptions = (sel) => options([["", "— بدون —"], ...accountCustomers().map((c) => [c.id, c.name])], sel);

/* --------------------------- نموذج مشروع تصميم --------------------------- */

function designForm(existing = null) {
  const isEdit = !!existing;
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="form-grid">
      <div class="field"><label>المصمم المسؤول</label>
        <select id="d-designer">${options([["", "— غير محدّد —"], ...designers().map((u) => [u.id, u.name])], existing?.designerUid || "")}</select></div>
      <div class="field"><label>صاحب المشروع</label>
        <input id="d-owner" value="${escapeHtml(existing?.ownerName || "")}" placeholder="اسم صاحب المشروع"></div>
      <div class="field full"><label>تفاصيل المشروع</label>
        <textarea id="d-details" placeholder="وصف/متطلبات المشروع">${escapeHtml(existing?.details || "")}</textarea></div>
      <div class="field"><label>نوع العرض</label>
        <select id="d-offer">${options(OFFER_TYPES.map((o) => [o, o]), existing?.offerType || "")}</select></div>
      <div class="field"><label>حالة المشروع</label>
        <select id="d-status">${options(PROJECT_STATUSES.map((s) => [s, s]), existing?.status || "قيد العمل")}</select></div>
      <div class="field"><label>المبلغ الكلي</label>
        <input id="d-total" type="number" min="0" value="${existing?.totalAmount ?? ""}" placeholder="0"></div>
      <div class="field"><label>المبلغ المدفوع</label>
        <input id="d-paid" type="number" min="0" value="${existing?.paidAmount ?? ""}" placeholder="0"></div>
      <div class="field"><label>تاريخ التسليم المتوقع</label>
        <input id="d-delivery" type="date" value="${existing?.deliveryDate ? isoDate(existing.deliveryDate) : ""}"></div>
      <div class="field"><label>الزبون المرتبط (اختياري)</label>
        <select id="d-cust">${custOptions(existing?.customerUid || "")}</select></div>
      <div class="field full"><label>العرض القادم للزبون (اختياري)</label>
        <input id="d-next" value="${escapeHtml(existing?.nextPresentation || "")}" placeholder="موعد/تفاصيل التسليم القادم"></div>
    </div>`;

  openModal({
    title: isEdit ? "تعديل مشروع تصميم" : "مشروع تصميم جديد", wide: true, content,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: isEdit ? "حفظ" : "إضافة", class: "btn--primary", onClick: async (c) => {
          const g = (id) => content.querySelector(id);
          const owner = g("#d-owner").value.trim();
          if (!owner) return toast("أدخل صاحب المشروع", "error");
          const designer = designers().find((u) => u.id === g("#d-designer").value);
          const cust = accountCustomers().find((c) => c.id === g("#d-cust").value);
          const deliveryStr = g("#d-delivery").value;
          const data = {
            ownerName: owner,
            details: g("#d-details").value.trim(),
            offerType: g("#d-offer").value,
            nextPresentation: g("#d-next").value.trim(),
            status: g("#d-status").value,
            totalAmount: Number(g("#d-total").value) || 0,
            paidAmount: Number(g("#d-paid").value) || 0,
            deliveryDate: deliveryStr ? ts(new Date(deliveryStr + "T00:00:00")) : null,
            designerUid: designer?.id || "",
            designerName: designer?.name || "",
            customerUid: cust?.id || null,
            customerName: cust?.name || null,
          };
          try {
            if (isEdit) await updateAt(COL.projects, existing.id, data);
            else await addTo(COL.projects, { ...data, tasks: [], notes: [] });
            toast(isEdit ? "تم الحفظ" : "تمت الإضافة", "success"); c();
          } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
        },
      },
    ],
  });
}

function isoDate(v) {
  const d = toDate(v); if (!d) return "";
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

/* --------------------------- نموذج موقع تنفيذ --------------------------- */

function siteForm(existing = null) {
  const isEdit = !!existing;
  const execs = executors();
  const chosen = new Set(existing?.executorUids || (existing?.executorUid ? [existing.executorUid] : []));
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="form-grid">
      <div class="field"><label>مشروع تصميم مرتبط (اختياري)</label>
        <select id="s-project">${options([["", "— بدون —"], ...store.data.projects.map((p) => [p.id, p.ownerName + " — " + (p.offerType || "تصميم")])], existing?.projectId || "")}</select></div>
      <div class="field"><label>تصنيف التنفيذ</label>
        <select id="s-cat">${options(Object.entries(WORK_CATEGORIES), existing?.category || "general")}</select></div>
      <div class="field"><label>صاحب المشروع</label>
        <input id="s-owner" value="${escapeHtml(existing?.ownerName || "")}" placeholder="اسم صاحب المشروع"></div>
      <div class="field"><label>اسم/عنوان الموقع</label>
        <input id="s-name" value="${escapeHtml(existing?.siteName || "")}" placeholder="اسم الموقع"></div>
      <div class="field full"><label>وصف العنوان (اختياري)</label>
        <input id="s-addr" value="${escapeHtml(existing?.address || "")}" placeholder="وصف العنوان"></div>
      <div class="field"><label>خط العرض (Latitude)</label>
        <input id="s-lat" type="number" step="any" value="${existing?.lat ?? ""}"></div>
      <div class="field"><label>خط الطول (Longitude)</label>
        <input id="s-lng" type="number" step="any" value="${existing?.lng ?? ""}"></div>
      <div class="field"><label>نطاق الحضور (متر)</label>
        <input id="s-radius" type="number" min="10" value="${existing?.radius ?? 100}"></div>
      <div class="field"><label>مدة التنفيذ (أيام، اختياري)</label>
        <input id="s-duration" type="number" min="0" value="${existing?.durationDays ?? ""}"></div>
      <div class="field full"><label>المنفّذون المسندون</label>
        <div class="chips" id="s-execs">
          ${execs.map((u) => `<label class="chip ${chosen.has(u.id) ? "active" : ""}" data-ex="${u.id}">
            <input type="checkbox" value="${u.id}" ${chosen.has(u.id) ? "checked" : ""} hidden> ${escapeHtml(u.name)}</label>`).join("") || '<span class="muted">لا يوجد موظفو تنفيذ</span>'}
        </div></div>
      <div class="field full"><label>الزبون المرتبط (اختياري)</label>
        <select id="s-cust">${custOptions(existing?.customerUid || "")}</select></div>
    </div>
    <button class="btn btn--ghost btn--sm" id="s-loc" type="button" style="margin-top:6px">📍 التقاط موقعي الحالي</button>`;

  // تفعيل الرقاقات (chips) للاختيار المتعدّد
  content.querySelectorAll("#s-execs .chip").forEach((chip) => {
    chip.addEventListener("click", (e) => {
      e.preventDefault();
      const cb = chip.querySelector("input");
      cb.checked = !cb.checked;
      chip.classList.toggle("active", cb.checked);
    });
  });
  // تعبئة صاحب المشروع من المشروع المختار
  content.querySelector("#s-project").addEventListener("change", (e) => {
    const p = store.data.projects.find((x) => x.id === e.target.value);
    if (p && !content.querySelector("#s-owner").value.trim()) content.querySelector("#s-owner").value = p.ownerName || "";
  });
  content.querySelector("#s-loc").onclick = () => {
    if (!navigator.geolocation) return toast("المتصفح لا يدعم تحديد الموقع", "error");
    navigator.geolocation.getCurrentPosition((pos) => {
      content.querySelector("#s-lat").value = pos.coords.latitude.toFixed(6);
      content.querySelector("#s-lng").value = pos.coords.longitude.toFixed(6);
      toast("تم التقاط الموقع", "success");
    }, () => toast("تعذّر تحديد الموقع", "error"));
  };

  openModal({
    title: isEdit ? "تعديل موقع تنفيذ" : "موقع تنفيذ جديد", wide: true, content,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: isEdit ? "حفظ" : "إضافة", class: "btn--primary", onClick: async (c) => {
          const g = (id) => content.querySelector(id);
          const owner = g("#s-owner").value.trim();
          const name = g("#s-name").value.trim();
          if (!owner) return toast("أدخل صاحب المشروع", "error");
          if (!name) return toast("أدخل اسم الموقع", "error");
          const ids = [...content.querySelectorAll("#s-execs input:checked")].map((i) => i.value);
          const chosenExecs = execs.filter((u) => ids.includes(u.id));
          const lat = g("#s-lat").value, lng = g("#s-lng").value;
          const proj = store.data.projects.find((p) => p.id === g("#s-project").value);
          const cust = accountCustomers().find((c) => c.id === g("#s-cust").value);
          const data = {
            ownerName: owner, siteName: name, address: g("#s-addr").value.trim(),
            lat: lat === "" ? null : Number(lat), lng: lng === "" ? null : Number(lng),
            radius: Number(g("#s-radius").value) || 100,
            durationDays: g("#s-duration").value ? Number(g("#s-duration").value) : null,
            projectId: proj?.id || null,
            category: g("#s-cat").value,
            executorUid: chosenExecs[0]?.id || null,
            executorName: chosenExecs[0]?.name || null,
            executorUids: chosenExecs.map((u) => u.id),
            executorNames: chosenExecs.map((u) => u.name),
            customerUid: cust?.id || (proj?.customerUid || null),
            customerName: cust?.name || (proj?.customerName || null),
          };
          try {
            if (isEdit) await updateAt(COL.sites, existing.id, data);
            else await addTo(COL.sites, data);
            toast(isEdit ? "تم الحفظ" : "تمت الإضافة", "success"); c();
          } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
        },
      },
    ],
  });
}

/* --------------------------- تفاصيل مشروع تصميم --------------------------- */

function designDetail(p, user) {
  const reports = store.data.dailyReports.filter((r) => r.projectId === p.id);
  const receipts = store.data.receipts.filter((r) => r.projectId === p.id);
  const prog = projectProgress(p);

  const body = document.createElement("div");
  const renderBody = () => {
    const tasks = p.tasks || [];
    const notes = p.notes || [];
    body.innerHTML = `
      <div class="kv-list">
        ${kv("صاحب المشروع", escapeHtml(p.ownerName || "—"))}
        ${kv("المصمم", escapeHtml(p.designerName || "—"))}
        ${kv("نوع العرض", escapeHtml(p.offerType || "—"))}
        ${kv("الحالة", badge(p.status || "—", "b-olive"))}
        ${kv("التسليم", fmtDate(p.deliveryDate))}
        ${kv("المبلغ الكلي", money(p.totalAmount))}
        ${kv("المدفوع", money(p.paidAmount), "pos")}
        ${kv("المتبقّي", money(remainingAmount(p)), "neg")}
        ${p.nextPresentation ? kv("العرض القادم", escapeHtml(p.nextPresentation)) : ""}
        ${prog != null ? kv("نسبة الإنجاز", `${prog}%`) : ""}
      </div>
      ${p.details ? `<div class="card" style="margin-top:12px"><div class="card__body">${escapeHtml(p.details)}</div></div>` : ""}

      <h4 style="margin:16px 0 8px">📋 المهام (${tasks.length})</h4>
      <div class="kv-list" id="task-list">
        ${tasks.map((t, i) => `<div class="kv">
          <span class="kv__k"><input type="checkbox" data-task="${i}" ${t.done ? "checked" : ""}> ${escapeHtml(t.title)} ${t.days ? `<span class="muted">(${t.days} يوم)</span>` : ""}</span>
          <span class="kv__v"><button class="mini mini--del" data-taskdel="${i}">حذف</button></span></div>`).join("") || '<div class="muted">لا مهام</div>'}
      </div>
      <div style="display:flex;gap:6px;margin-top:8px">
        <input id="task-title" placeholder="مهمة جديدة" style="flex:1">
        <input id="task-days" type="number" min="0" placeholder="أيام" style="width:80px">
        <button class="btn btn--ghost btn--sm" id="task-add">إضافة</button>
      </div>

      <h4 style="margin:16px 0 8px">🗒️ الملاحظات (${notes.length})</h4>
      <div class="kv-list">
        ${notes.map((n) => `<div class="kv"><span class="kv__k">${escapeHtml(n.text)}</span>
          <span class="kv__v muted">${escapeHtml(n.author || "")} ${n.createdAt ? "• " + fmtDate(n.createdAt) : ""}</span></div>`).join("") || '<div class="muted">لا ملاحظات</div>'}
      </div>
      <div style="display:flex;gap:6px;margin-top:8px">
        <input id="note-text" placeholder="ملاحظة جديدة" style="flex:1">
        <button class="btn btn--ghost btn--sm" id="note-add">إضافة</button>
      </div>

      <h4 style="margin:16px 0 8px">📝 التقارير المرتبطة (${reports.length})</h4>
      <div class="kv-list">
        ${reports.slice(0, 20).map((r) => kv(`${escapeHtml(r.userName || "موظف")} — ${fmtDate(r.date)}`, escapeHtml((r.content || "").slice(0, 60)))).join("") || '<div class="muted">لا تقارير</div>'}
      </div>
      ${receipts.length ? `<h4 style="margin:16px 0 8px">🧾 وصولات (${receipts.length})</h4>
      <div class="kv-list">${receipts.slice(0, 20).map((r) => kv(fmtDate(r.date), money(r.amount), r.expense ? "neg" : "pos")).join("")}</div>` : ""}
    `;

    // ربط المهام والملاحظات
    body.querySelectorAll("[data-task]").forEach((cb) => cb.onchange = async () => {
      const t = [...(p.tasks || [])];
      t[+cb.dataset.task] = { ...t[+cb.dataset.task], done: cb.checked };
      p.tasks = t; await updateAt(COL.projects, p.id, { tasks: t }); renderBody();
    });
    body.querySelectorAll("[data-taskdel]").forEach((b) => b.onclick = async () => {
      const t = [...(p.tasks || [])]; t.splice(+b.dataset.taskdel, 1);
      p.tasks = t; await updateAt(COL.projects, p.id, { tasks: t }); renderBody();
    });
    body.querySelector("#task-add").onclick = async () => {
      const title = body.querySelector("#task-title").value.trim();
      if (!title) return;
      const t = [...(p.tasks || []), { title, days: Number(body.querySelector("#task-days").value) || 0, done: false }];
      p.tasks = t; await updateAt(COL.projects, p.id, { tasks: t }); renderBody();
    };
    body.querySelector("#note-add").onclick = async () => {
      const text = body.querySelector("#note-text").value.trim();
      if (!text) return;
      const n = [...(p.notes || []), { text, author: user?.name || "مدير النظام", createdAt: ts(new Date()) }];
      p.notes = n; await updateAt(COL.projects, p.id, { notes: n }); renderBody();
    };
  };
  renderBody();
  openModal({ title: `مشروع: ${p.ownerName || ""}`, wide: true, content: body });
}

/* --------------------------- تفاصيل موقع تنفيذ --------------------------- */

function siteDetail(s) {
  const reports = store.data.executionReports.filter((r) => r.siteId === s.id);
  const receipts = store.data.receipts.filter((r) => r.siteId === s.id);
  const expenses = store.data.expenses.filter((e) => e.siteId === s.id);
  const checkins = store.data.siteCheckins.filter((c) => c.siteId === s.id);
  const prog = siteProgress(s);
  const execNames = (s.executorNames && s.executorNames.length ? s.executorNames : (s.executorName ? [s.executorName] : [])).join("، ") || "—";

  const content = `
    <div class="kv-list">
      ${kv("صاحب المشروع", escapeHtml(s.ownerName || "—"))}
      ${kv("التصنيف", badge(categoryLabel(s.category), "b-olive"))}
      ${kv("المنفّذون", escapeHtml(execNames))}
      ${kv("العنوان", escapeHtml(s.address || "—"))}
      ${s.lat != null && s.lng != null ? kv("الموقع", `<a class="mini mini--view" target="_blank" href="https://www.google.com/maps/search/?api=1&query=${s.lat},${s.lng}">📍 خريطة</a>`) : ""}
      ${kv("نطاق الحضور", (s.radius || 100) + " م")}
      ${s.durationDays ? kv("المدة المتوقعة", s.durationDays + " يوم") : ""}
      ${prog != null ? kv("نسبة الإنجاز التقديرية", `${prog}%`) : ""}
    </div>
    <h4 style="margin:16px 0 8px">🏗️ تقارير التنفيذ (${reports.length})</h4>
    <div class="kv-list">${reports.slice(0, 20).map((r) =>
      kv(`${escapeHtml(r.executorName || "منفّذ")} — ${fmtDate(r.date)}`, `${escapeHtml((r.documentsNotes || "").slice(0, 50))} ${(r.photoUrls || []).length ? `<span class="badge-s b-blue">${r.photoUrls.length} صور</span>` : ""}`)
    ).join("") || '<div class="muted">لا تقارير</div>'}</div>
    ${receipts.length ? `<h4 style="margin:16px 0 8px">🧾 الوصولات (${receipts.length})</h4>
      <div class="kv-list">${receipts.slice(0, 20).map((r) => kv(`${fmtDate(r.date)} — ${escapeHtml(r.description || "")}`, money(r.amount), r.expense ? "neg" : "pos")).join("")}</div>` : ""}
    ${expenses.length ? `<h4 style="margin:16px 0 8px">💵 السلف والصرفيات (${expenses.length})</h4>
      <div class="kv-list">${expenses.slice(0, 20).map((e) => kv(`${fmtDate(e.date)} — ${e.type === "advance" ? "سلفة" : "صرفية"}`, money(e.amount), "neg")).join("")}</div>` : ""}
    ${checkins.length ? `<h4 style="margin:16px 0 8px">📍 تسجيلات الدخول (${checkins.length})</h4>
      <div class="kv-list">${checkins.slice(0, 20).map((c) => kv(escapeHtml(c.executorName || "منفّذ"), fmtDateTime(c.time))).join("")}</div>` : ""}`;
  openModal({ title: `موقع: ${s.siteName || ""}`, wide: true, content });
}

/* ----------------------------- عرض الصفحة ----------------------------- */

function render(container, { user } = {}) {
  const draw = () => {
    const cMap = {}; accountCustomers().forEach((c) => cMap[c.id] = c.name);
    const q = search.toLowerCase();

    const dProjects = store.data.projects.filter((p) => {
      if (typeFilter === "execution") return false;
      if (statusFilter && p.status !== statusFilter) return false;
      if (custFilter && p.customerUid !== custFilter) return false;
      if (q && !(`${p.ownerName} ${p.details} ${p.designerName}`.toLowerCase().includes(q))) return false;
      return true;
    });
    const sites = store.data.sites.filter((s) => {
      if (typeFilter === "design") return false;
      if (custFilter && s.customerUid !== custFilter) return false;
      if (catFilter && s.category !== catFilter) return false;
      if (q && !(`${s.ownerName} ${s.siteName} ${s.address}`.toLowerCase().includes(q))) return false;
      return true;
    });

    const filters = `
      <div class="filters">
        <label class="f-field f-grow"><span>بحث</span><input id="p-search" value="${escapeHtml(search)}" placeholder="بحث بالاسم أو التفاصيل"></label>
        <div class="f-field"><span>النوع</span><div class="chips">
          ${[["all", "الكل"], ["design", "تصميم"], ["execution", "تنفيذ"]].map(([v, l]) =>
            `<button class="chip ${typeFilter === v ? "active" : ""}" data-type="${v}">${l}</button>`).join("")}
        </div></div>
        <label class="f-field"><span>حالة التصميم</span>
          <select id="p-status"><option value="">الكل</option>${options(PROJECT_STATUSES.map((s) => [s, s]), statusFilter)}</select></label>
        <label class="f-field"><span>تصنيف التنفيذ</span>
          <select id="p-cat"><option value="">الكل</option>${options(Object.entries(WORK_CATEGORIES), catFilter)}</select></label>
        <label class="f-field"><span>الزبون</span>
          <select id="p-cust"><option value="">الكل</option>${options(accountCustomers().map((c) => [c.id, c.name]), custFilter)}</select></label>
        <button class="btn btn--primary btn--sm" id="p-add">➕ إضافة</button>
      </div>`;

    // بطاقات التصميم
    const designCards = dProjects.map((p, i) => {
      const prog = projectProgress(p);
      return `<div class="item-card">
        <div class="item-card__head">
          <div><div class="item-card__title">${escapeHtml(p.ownerName || "مشروع")}</div>
          <div class="item-card__sub">${escapeHtml(p.offerType || "تصميم")} • ${escapeHtml(p.designerName || "غير مسند")}</div></div>
          <span class="spacer"></span>${badge(p.status || "—", "b-olive")}
        </div>
        ${p.details ? `<div class="item-card__sub">${escapeHtml(p.details.slice(0, 90))}${p.details.length > 90 ? "…" : ""}</div>` : ""}
        <div class="item-card__row">${badge("كلي: " + money(p.totalAmount), "b-gray")} ${badge("متبقٍّ: " + money(remainingAmount(p)), "b-gold")}</div>
        ${prog != null ? `<div class="progress"><i style="width:${prog}%"></i></div>` : ""}
        <div class="item-card__foot">
          <button class="mini mini--view" data-d="det" data-i="${i}">تفاصيل</button>
          <button class="mini mini--edit" data-d="edit" data-i="${i}">تعديل</button>
          <span class="spacer"></span>
          <button class="mini mini--del" data-d="del" data-i="${i}">حذف</button>
        </div></div>`;
    }).join("");

    // بطاقات المواقع
    const siteCards = sites.map((s, i) => {
      const prog = siteProgress(s);
      const execCount = (s.executorUids && s.executorUids.length) || (s.executorUid ? 1 : 0);
      return `<div class="item-card">
        <div class="item-card__head">
          <div><div class="item-card__title">${escapeHtml(s.siteName || "موقع")}</div>
          <div class="item-card__sub">${escapeHtml(s.ownerName || "")}</div></div>
          <span class="spacer"></span>${badge(categoryLabel(s.category), "b-blue")}
        </div>
        <div class="item-card__row">
          ${s.address ? `<span class="item-card__sub">📍 ${escapeHtml(s.address.slice(0, 40))}</span>` : ""}
          ${badge(`${execCount} منفّذ`, "b-gray")}
        </div>
        ${prog != null ? `<div class="progress"><i style="width:${prog}%"></i></div>` : ""}
        <div class="item-card__foot">
          <button class="mini mini--view" data-s="det" data-i="${i}">تفاصيل</button>
          <button class="mini mini--edit" data-s="edit" data-i="${i}">تعديل</button>
          <span class="spacer"></span>
          <button class="mini mini--del" data-s="del" data-i="${i}">حذف</button>
        </div></div>`;
    }).join("");

    const showDesign = typeFilter !== "execution";
    const showExec = typeFilter !== "design";
    container.innerHTML = `${filters}
      ${showDesign ? card(`مشاريع التصميم (${dProjects.length})`, "📐",
        dProjects.length ? `<div class="cards-grid">${designCards}</div>` : emptyState("لا مشاريع تصميم مطابقة", "📐")) : ""}
      ${showExec ? card(`مواقع التنفيذ (${sites.length})`, "🏗️",
        sites.length ? `<div class="cards-grid">${siteCards}</div>` : emptyState("لا مواقع تنفيذ مطابقة", "🏗️")) : ""}`;

    // ربط الفلاتر
    const se = container.querySelector("#p-search");
    se.oninput = (e) => { search = e.target.value; };
    se.onchange = () => draw();
    se.onkeydown = (e) => { if (e.key === "Enter") draw(); };
    container.querySelectorAll("[data-type]").forEach((b) => b.onclick = () => { typeFilter = b.dataset.type; draw(); });
    container.querySelector("#p-status").onchange = (e) => { statusFilter = e.target.value; draw(); };
    container.querySelector("#p-cat").onchange = (e) => { catFilter = e.target.value; draw(); };
    container.querySelector("#p-cust").onchange = (e) => { custFilter = e.target.value; draw(); };
    container.querySelector("#p-add").onclick = () => addSheet(user);

    // ربط بطاقات التصميم
    container.querySelectorAll("[data-d]").forEach((b) => b.onclick = async () => {
      const p = dProjects[+b.dataset.i];
      if (b.dataset.d === "det") designDetail(p, user);
      else if (b.dataset.d === "edit") designForm(p);
      else if (b.dataset.d === "del" && await confirmDialog(`حذف مشروع «${p.ownerName}» وكل تقاريره ووصولاته؟`, { okText: "حذف" })) {
        try { await deleteProjectCascade(p.id); toast("تم الحذف", "success"); } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
      }
    });
    // ربط بطاقات المواقع
    container.querySelectorAll("[data-s]").forEach((b) => b.onclick = async () => {
      const s = sites[+b.dataset.i];
      if (b.dataset.s === "det") siteDetail(s);
      else if (b.dataset.s === "edit") siteForm(s);
      else if (b.dataset.s === "del" && await confirmDialog(`حذف موقع «${s.siteName}» وكل تقاريره ووصولاته وصرفياته؟`, { okText: "حذف" })) {
        try { await deleteSiteCascade(s.id); toast("تم الحذف", "success"); } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
      }
    });
  };

  draw();
  return onStore(draw);
}

function addSheet(user) {
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="cards-grid">
      <div class="item-card" id="add-design" style="cursor:pointer">
        <div class="item-card__title">📐 مشروع تصميم</div>
        <div class="item-card__sub">المتطلبات + إسناد مصمم + ربط زبون + العقد المالي</div>
      </div>
      <div class="item-card" id="add-site" style="cursor:pointer">
        <div class="item-card__title">🏗️ موقع تنفيذ</div>
        <div class="item-card__sub">موقع GPS + إسناد منفّذين + التصنيف + ربط زبون</div>
      </div>
    </div>`;
  const { close } = openModal({ title: "إضافة جديد", wide: true, content });
  content.querySelector("#add-design").onclick = () => { close(); designForm(); };
  content.querySelector("#add-site").onclick = () => { close(); siteForm(); };
}

export default {
  title: "المشاريع والمواقع",
  sub: "مشاريع التصميم ومواقع التنفيذ",
  needs: ["projects", "sites", "receipts", "expenses", "siteCheckins", "executionReports", "dailyReports", "accountCustomers", "users"],
  render,
};
