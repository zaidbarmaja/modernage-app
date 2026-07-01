// ===============================================================
//  صفحة: المستخدمون — إنشاء/تعديل الحسابات، الصلاحيات، كلمات المرور،
//  التفعيل/التعطيل، عرض الحضور، والحذف. مطابق لإدارة المستخدمين في التطبيق.
// ===============================================================

import { store, onStore, usersById } from "../store.js";
import {
  createEmployeeAccount, createCustomerAccount, updateAt, updateUserRole,
  setUserActive, setUserPassword, deleteUserPermanently, COL,
} from "../data.js";
import { card, badge, emptyState, options } from "../ui.js";
import { attMetrics } from "./attendance.js";
import {
  ROLES, DEPARTMENTS, WORK_CATEGORIES, roleLabel, deptLabel, categoryLabel,
  minToHHMM, hhmmToMin, loginKeys, generateAccessCode, openModal, confirmDialog,
  toast, fmtDate, fmtTime, fmtDuration, escapeHtml,
} from "../utils.js";

let tab = "staff";   // staff | customers
let search = "";

/* --------------------------- النماذج --------------------------- */

function employeeForm(existing = null) {
  const isEdit = !!existing;
  const roleOpts = [
    ["executionEmployee", "موظف التنفيذ"],
    ["designEmployee", "موظف التصميم"],
    ["accounting", "المحاسبة"],
  ];
  const catOpts = Object.entries(WORK_CATEGORIES);
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="form-grid">
      <div class="field full"><label>اسم الموظف (اسم الدخول)</label>
        <input id="e-name" value="${escapeHtml(existing?.name || "")}" placeholder="مثال: أحمد علي"></div>
      <div class="field"><label>رقم الهاتف (اختياري)</label>
        <input id="e-phone" value="${escapeHtml(existing?.phone || "")}" placeholder="اختياري — دخول بديل"></div>
      ${isEdit ? "" : `<div class="field"><label>رمز الدخول (٤ أرقام)</label>
        <input id="e-pass" placeholder="مثال: 1234" maxlength="12"></div>`}
      <div class="field"><label>الدور</label>
        <select id="e-role">${options(roleOpts, existing?.role || "executionEmployee")}</select></div>
      <div class="field" id="e-cat-wrap"><label>تصنيف التنفيذ</label>
        <select id="e-cat">${options(catOpts, existing?.workCategory || "general")}</select></div>
      <div class="field"><label>بداية الدوام (اختياري)</label>
        <input id="e-start" type="time" value="${minToHHMM(existing?.workStartMin)}"></div>
      <div class="field"><label>نهاية الدوام (اختياري)</label>
        <input id="e-end" type="time" value="${minToHHMM(existing?.workEndMin)}"></div>
    </div>
    <p class="hint">💡 يدخل الموظف باسمه (أو هاتفه) ورمز الدخول. أوقات الدوام تُترك فارغة لاستخدام دوام الشركة الافتراضي.</p>`;

  const roleSel = content.querySelector("#e-role");
  const catWrap = content.querySelector("#e-cat-wrap");
  const syncCat = () => { catWrap.style.display = roleSel.value === "executionEmployee" ? "" : "none"; };
  roleSel.addEventListener("change", syncCat); syncCat();

  const { close } = openModal({
    title: isEdit ? "تعديل موظف" : "إضافة موظف",
    wide: true,
    content,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: isEdit ? "حفظ" : "إنشاء الحساب", class: "btn--primary",
        onClick: async (c) => {
          const name = content.querySelector("#e-name").value.trim();
          const phone = content.querySelector("#e-phone").value.trim();
          const role = content.querySelector("#e-role").value;
          const workCategory = content.querySelector("#e-cat").value;
          const workStartMin = hhmmToMin(content.querySelector("#e-start").value);
          const workEndMin = hhmmToMin(content.querySelector("#e-end").value);
          if (!name) return toast("أدخل اسم الموظف", "error");
          try {
            if (isEdit) {
              await updateAt(COL.users, existing.id, {
                name, phone, role, workCategory: role === "executionEmployee" ? workCategory : "general",
                workStartMin, workEndMin, loginNames: loginKeys(name, phone),
              });
              toast("تم حفظ التعديلات", "success");
            } else {
              const pass = content.querySelector("#e-pass").value.trim();
              if (!pass) return toast("أدخل رمز الدخول", "error");
              await createEmployeeAccount({ name, username: name, password: pass, role, workCategory, workStartMin, workEndMin, phone });
              toast("تم إنشاء حساب الموظف", "success");
            }
            c();
          } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
        },
      },
    ],
  });
  return close;
}

function customerForm() {
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="form-grid">
      <div class="field full"><label>اسم الزبون</label>
        <input id="c-name" placeholder="اسم الزبون"></div>
      <div class="field"><label>رقم الهاتف (اسم الدخول)</label>
        <input id="c-phone" placeholder="رقم الهاتف — ٧ أرقام على الأقل"></div>
      <div class="field"><label>رمز الوصول (٤ أرقام)</label>
        <div style="display:flex;gap:6px">
          <input id="c-code" value="${generateAccessCode()}" maxlength="8" style="flex:1">
          <button class="btn btn--ghost btn--sm" id="c-gen" type="button">🎲</button>
        </div></div>
      <div class="field full"><label>معلومات التواصل (اختياري)</label>
        <input id="c-contact" placeholder="عنوان / هاتف بديل / ملاحظات"></div>
    </div>
    <p class="hint">💡 يدخل الزبون برقم هاتفه ورمز الوصول، ويرى مشاريعه وتقاريره فقط.</p>`;

  content.querySelector("#c-gen").onclick = () =>
    content.querySelector("#c-code").value = generateAccessCode();

  const { close, body } = openModal({
    title: "إضافة زبون",
    wide: true,
    content,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: "إنشاء الحساب", class: "btn--primary",
        onClick: async (c, btn) => {
          const name = content.querySelector("#c-name").value.trim();
          const phone = content.querySelector("#c-phone").value.trim();
          const accessCode = content.querySelector("#c-code").value.trim();
          const contact = content.querySelector("#c-contact").value.trim();
          if (!name) return toast("أدخل اسم الزبون", "error");
          if (phone.replace(/\D/g, "").length < 7) return toast("رقم الهاتف قصير", "error");
          if (!accessCode) return toast("أدخل رمز الوصول", "error");
          try {
            await createCustomerAccount({ name, phone, accessCode, contact });
            // نعرض بيانات الدخول لتسليمها للزبون
            body.innerHTML = `<div class="result-box">
              <p>✅ تم إنشاء حساب الزبون. سلّمه بيانات الدخول:</p>
              <div class="kv-list">
                <div class="kv"><span class="kv__k">الاسم</span><span class="kv__v">${escapeHtml(name)}</span></div>
                <div class="kv"><span class="kv__k">رقم الدخول</span><span class="kv__v num">${escapeHtml(phone)}</span></div>
                <div class="kv"><span class="kv__k">رمز الوصول</span><span class="code">${escapeHtml(accessCode)}</span></div>
              </div></div>`;
            toast("تم إنشاء حساب الزبون", "success");
          } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
        },
      },
    ],
  });
  return close;
}

function roleDialog(u) {
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="form-grid">
      <div class="field"><label>الدور</label>
        <select id="r-role">${options(Object.entries(ROLES).map(([id, r]) => [id, r.label]), u.role)}</select></div>
      <div class="field"><label>القسم</label>
        <select id="r-dept">${options(Object.entries(DEPARTMENTS).map(([id, d]) => [id, d.label]), u.department || "none")}</select></div>
      <div class="field full" id="r-cat-wrap"><label>تصنيف التنفيذ</label>
        <select id="r-cat">${options(Object.entries(WORK_CATEGORIES), u.workCategory || "general")}</select></div>
    </div>`;
  const roleSel = content.querySelector("#r-role");
  const catWrap = content.querySelector("#r-cat-wrap");
  const sync = () => { catWrap.style.display = roleSel.value === "executionEmployee" ? "" : "none"; };
  roleSel.onchange = sync; sync();

  openModal({
    title: `تغيير صلاحية: ${u.name}`, content,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: "حفظ", class: "btn--primary", onClick: async (c) => {
          try {
            await updateUserRole(u.id, roleSel.value, content.querySelector("#r-dept").value, content.querySelector("#r-cat").value);
            toast("تم تحديث الصلاحية", "success"); c();
          } catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
        },
      },
    ],
  });
}

function passwordDialog(u) {
  const content = document.createElement("div");
  content.innerHTML = `
    <div class="field"><label>كلمة المرور/الرمز الجديد</label>
      <input id="p-pass" placeholder="٤ أحرف على الأقل"></div>
    <p class="hint">تُخزَّن مجزّأة بأمان (لا تُحفظ كنص). يدخل بها المستخدم فوراً.</p>`;
  openModal({
    title: `إعادة تعيين كلمة مرور: ${u.name}`, content,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: "تعيين", class: "btn--primary", onClick: async (c) => {
          const pass = content.querySelector("#p-pass").value.trim();
          if (pass.length < 4) return toast("الرمز قصير (٤ على الأقل)", "error");
          try { await setUserPassword(u.id, pass); toast("تم تعيين كلمة المرور", "success"); c(); }
          catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
        },
      },
    ],
  });
}

function attendanceDialog(u) {
  const recs = store.data.attendance.filter((a) => a.uid === u.id).slice(0, 60);
  const body = recs.length ? `<div class="table-wrap"><table class="data">
    <thead><tr><th>التاريخ</th><th>الدخول</th><th>الخروج</th><th>العمل</th><th>الإضافي</th></tr></thead>
    <tbody>${recs.map((r) => { const m = attMetrics(r); return `<tr>
      <td class="num">${fmtDate(r.checkIn)}</td>
      <td class="num">${fmtTime(r.checkIn)}</td>
      <td class="num">${r.checkOut ? fmtTime(r.checkOut) : "—"}</td>
      <td class="num">${m.open ? "—" : fmtDuration(m.worked)}</td>
      <td class="num">${m.overtime ? fmtDuration(m.overtime) : "—"}</td>
    </tr>`; }).join("")}</tbody></table></div>` : emptyState("لا سجلات حضور لهذا الموظف", "🗓️");
  openModal({ title: `حضور: ${u.name}`, wide: true, content: body });
}

/* ---------------------------- الصفحة ---------------------------- */

function render(container, { user } = {}) {
  const draw = () => {
    const all = store.data.users;
    const list = all.filter((u) => {
      const isCust = u.role === "customer";
      if (tab === "staff" && isCust) return false;
      if (tab === "customers" && !isCust) return false;
      if (search) {
        const q = search.toLowerCase();
        if (!(u.name || "").toLowerCase().includes(q) && !(u.phone || "").includes(q)) return false;
      }
      return true;
    });

    const head = `
      <div class="filters">
        <div class="chips">
          <button class="chip ${tab === "staff" ? "active" : ""}" data-tab="staff">الطاقم</button>
          <button class="chip ${tab === "customers" ? "active" : ""}" data-tab="customers">الزبائن</button>
        </div>
        <label class="f-field f-grow"><span>بحث</span>
          <input id="u-search" value="${escapeHtml(search)}" placeholder="بحث بالاسم أو الهاتف"></label>
        <button class="btn btn--primary btn--sm" id="add-emp">➕ موظف</button>
        <button class="btn btn--primary btn--sm" id="add-cust">➕ زبون</button>
      </div>`;

    const rows = list.map((u, i) => {
      const isSelf = u.id === user?.uid;
      const schedule = (u.workStartMin != null && u.workEndMin != null)
        ? `${minToHHMM(u.workStartMin)}–${minToHHMM(u.workEndMin)}` : "—";
      const activeBadge = u.active === false ? badge("معطّل", "b-red") : badge("مفعّل", "b-green");
      return `<tr>
        <td><b>${escapeHtml(u.name || "—")}</b>${u.contact ? `<br><span class="muted">${escapeHtml(u.contact)}</span>` : ""}</td>
        <td>${badge(roleLabel(u.role), "b-olive")}</td>
        <td class="num">${escapeHtml(u.phone || "—")}</td>
        <td>${u.role === "executionEmployee" ? escapeHtml(categoryLabel(u.workCategory)) : deptLabel(u.department)}</td>
        <td class="num">${schedule}</td>
        <td>${activeBadge}</td>
        <td class="row-actions">
          <button class="mini mini--edit" data-act="edit" data-i="${i}">تعديل</button>
          <button class="mini mini--view" data-act="role" data-i="${i}">صلاحية</button>
          <button class="mini mini--view" data-act="pass" data-i="${i}">كلمة المرور</button>
          ${u.role !== "customer" ? `<button class="mini mini--view" data-act="att" data-i="${i}">الحضور</button>` : ""}
          <button class="mini ${u.active === false ? "mini--ok" : "mini--edit"}" data-act="toggle" data-i="${i}" ${isSelf ? "disabled" : ""}>${u.active === false ? "تفعيل" : "تعطيل"}</button>
          <button class="mini mini--del" data-act="del" data-i="${i}" ${isSelf ? "disabled" : ""}>حذف</button>
        </td>
      </tr>`;
    }).join("");

    const table = list.length ? `<div class="table-wrap"><table class="data">
      <thead><tr><th>الاسم</th><th>الدور</th><th>الهاتف</th><th>القسم/التصنيف</th><th>الدوام</th><th>الحالة</th><th>إجراءات</th></tr></thead>
      <tbody>${rows}</tbody></table></div>` : emptyState("لا مستخدمين في هذا التبويب", "👥");

    container.innerHTML = `${head}${card(`${tab === "staff" ? "الطاقم" : "الزبائن"} (${list.length})`, "👥", table, "", "pad0")}`;

    // ربط
    container.querySelectorAll("[data-tab]").forEach((b) => b.onclick = () => { tab = b.dataset.tab; draw(); });
    const s = container.querySelector("#u-search");
    s.oninput = (e) => { search = e.target.value; };
    s.onchange = () => draw();
    s.onkeydown = (e) => { if (e.key === "Enter") draw(); };
    container.querySelector("#add-emp").onclick = () => employeeForm();
    container.querySelector("#add-cust").onclick = () => customerForm();

    container.querySelectorAll("[data-act]").forEach((b) => b.onclick = async () => {
      const u = list[+b.dataset.i];
      switch (b.dataset.act) {
        case "edit": u.role === "customer" ? toast("تعديل الزبائن من صفحة الحساب", "info") : employeeForm(u); break;
        case "role": roleDialog(u); break;
        case "pass": passwordDialog(u); break;
        case "att": attendanceDialog(u); break;
        case "toggle":
          try { await setUserActive(u.id, u.active === false); toast("تم التحديث", "success"); }
          catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
          break;
        case "del":
          if (await confirmDialog(`حذف «${u.name}» نهائياً؟ لا يمكن التراجع.`, { okText: "حذف نهائي" })) {
            try { await deleteUserPermanently(u.id); toast("تم الحذف", "success"); }
            catch (ex) { toast("خطأ: " + (ex.message || ex), "error"); }
          }
          break;
      }
    });
  };

  draw();
  return onStore(draw);
}

export default {
  title: "المستخدمون",
  sub: "إدارة الحسابات والصلاحيات وكلمات المرور",
  needs: ["users", "attendance"],
  render,
};
