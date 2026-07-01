// ===============================================================
//  صفحة: الإشعارات — بثّ فوري للجميع + تنبيهات يومية مجدولة + سجل الإشعارات
//  النماذج التفاعلية (البثّ + إضافة تنبيه) لا تُعاد بناؤها مع تحديثات القاعدة،
//  فلا يُمحى ما يكتبه المستخدم.
// ===============================================================

import { store, onStore, usersById } from "../store.js";
import {
  broadcastNotification, markNotificationRead,
  addReminder, updateReminder, deleteReminder,
} from "../data.js";
import { card, emptyState, badge } from "../ui.js";
import {
  fmtDateTime, toast, escapeHtml, minToHHMM, hhmmToMin,
  openModal, confirmDialog,
} from "../utils.js";

function typeBadge(t) {
  const map = {
    broadcast: ["بثّ عام", "b-blue"],
    site_checkin: ["دخول موقع", "b-olive"],
  };
  const [lab, cls] = map[t] || [t || "إشعار", "b-gray"];
  return badge(lab, cls);
}

/* --------------------- التنبيهات اليومية المجدولة --------------------- */

/** نافذة إضافة/تعديل تنبيه مجدول. */
function reminderForm(existing) {
  const isEdit = !!existing;
  const box = document.createElement("div");
  box.innerHTML = `
    <div class="field">
      <label>وقت التنبيه</label>
      <input type="time" id="r-time" value="${minToHHMM(existing?.minute ?? 600)}">
    </div>
    <div class="field">
      <label>العنوان</label>
      <input id="r-title" maxlength="80" value="${escapeHtml(existing?.title || "")}" placeholder="تذكير بتسجيل الدخول">
    </div>
    <div class="field">
      <label>النص</label>
      <textarea id="r-body" placeholder="حان وقت الدوام — لا تنسَ تسجيل حضورك.">${escapeHtml(existing?.body || "")}</textarea>
    </div>`;
  openModal({
    title: isEdit ? "تعديل التنبيه المجدول" : "إضافة تنبيه مجدول",
    content: box,
    actions: [
      { label: "إلغاء", class: "btn--ghost", onClick: (c) => c() },
      {
        label: "حفظ", class: "btn--primary", onClick: async (c) => {
          const minute = hhmmToMin(box.querySelector("#r-time").value);
          const title = box.querySelector("#r-title").value.trim();
          const body = box.querySelector("#r-body").value.trim();
          if (minute == null) return toast("اختر وقت التنبيه", "error");
          if (!title && !body) return toast("اكتب عنواناً أو نصاً", "error");
          try {
            if (isEdit) await updateReminder(existing.id, { minute, title, body });
            else await addReminder({ minute, title, body, enabled: true });
            toast("تم الحفظ", "success");
            c();
          } catch (e) {
            toast("تعذّر الحفظ: " + (e.message || e), "error");
          }
        },
      },
    ],
  });
}

function drawReminders(container) {
  const rems = store.data.scheduledReminders || [];
  const rows = rems.map((r) => {
    const off = r.enabled === false;
    return `<tr>
      <td class="num">${minToHHMM(r.minute ?? 0)}</td>
      <td><b>${escapeHtml(r.title || "—")}</b><br><span class="muted">${escapeHtml(r.body || "")}</span></td>
      <td>${off ? badge("معطّل", "b-gray") : badge("مُفعّل", "b-green")}</td>
      <td class="row-actions">
        <button class="mini mini--ok" data-toggle="${r.id}" data-en="${off ? 1 : 0}">${off ? "تفعيل" : "تعطيل"}</button>
        <button class="mini mini--edit" data-edit="${r.id}">تعديل</button>
        <button class="mini mini--del" data-del="${r.id}">حذف</button>
      </td>
    </tr>`;
  }).join("");

  const table = rems.length ? `
    <div class="table-wrap"><table class="data">
      <thead><tr><th>الوقت</th><th>التنبيه</th><th>الحالة</th><th></th></tr></thead>
      <tbody>${rows}</tbody>
    </table></div>`
    : emptyState("لا توجد تنبيهات مجدولة. أضِف تنبيهاً ليصل الموظفين يومياً في وقته.", "⏰");

  const wrap = container.querySelector("#rem-list");
  if (!wrap) return;
  wrap.innerHTML = card("التنبيهات اليومية المجدولة", "⏰", `
    <p class="hint">📌 تصل الموظفين تلقائياً كل يوم في وقتها (تذكير بالدخول/الخروج…) حتى والتطبيق مغلق. تُطبَّق التغييرات على جهاز الموظف عند فتحه للتطبيق. إن لم تُضِف أيّاً، يرسل التطبيق افتراضياً تذكيراً بالدخول عند بداية الدوام وبالخروج عند نهايته.</p>
    <div class="modal__actions" style="margin-bottom:12px">
      <button class="btn btn--primary btn--sm" id="rem-add">➕ إضافة تنبيه</button>
    </div>
    ${table}`);

  wrap.querySelector("#rem-add").onclick = () => reminderForm(null);
  wrap.querySelectorAll("[data-edit]").forEach((b) =>
    b.onclick = () => {
      const r = (store.data.scheduledReminders || []).find((x) => x.id === b.dataset.edit);
      if (r) reminderForm(r);
    });
  wrap.querySelectorAll("[data-toggle]").forEach((b) =>
    b.onclick = () => updateReminder(b.dataset.toggle, { enabled: b.dataset.en === "1" }).catch(() => {}));
  wrap.querySelectorAll("[data-del]").forEach((b) =>
    b.onclick = async () => {
      if (await confirmDialog("حذف هذا التنبيه المجدول؟")) {
        deleteReminder(b.dataset.del).catch(() => {});
      }
    });
}

/* ----------------------------- الصفحة ----------------------------- */

function render(container, { user } = {}) {
  // الهيكل الثابت: نموذج البثّ + حاوية التنبيهات المجدولة + حاوية سجل الإشعارات.
  container.innerHTML = `
    ${card("بثّ إشعار فوري للجميع", "📣", `
      <div class="field">
        <label>العنوان</label>
        <input id="n-title" placeholder="عنوان الإشعار" maxlength="80" autocomplete="off">
      </div>
      <div class="field">
        <label>النص</label>
        <textarea id="n-body" placeholder="نص الإشعار الذي سيصل لكل المستخدمين"></textarea>
      </div>
      <p class="hint">📌 يصل الإشعار إلى كل مستخدمي التطبيق، ويظهر لكلٍّ منهم داخل التطبيق في جرس الإشعارات 🔔 عند فتحه.</p>
      <div class="modal__actions" style="margin-top:6px">
        <button class="btn btn--primary" id="n-send">📤 إرسال للجميع</button>
      </div>`)}
    <div id="rem-list"></div>
    <div id="notif-list"></div>`;

  // تحديث سجل الإشعارات فقط (لا يمسّ النماذج).
  const drawList = () => {
    const notifs = store.data.notifications;
    const uMap = usersById();
    const rows = notifs.slice(0, 80).map((n) => {
      const to = n.toUid ? (uMap[n.toUid]?.name || "مستخدم") : "الإدارة";
      const from = n.fromName || (uMap[n.fromUid]?.name || "—");
      return `<tr class="${n.read ? "" : "unread"}">
        <td>${typeBadge(n.type)}</td>
        <td><b>${escapeHtml(n.title || "—")}</b><br><span class="muted">${escapeHtml((n.body || "").slice(0, 70))}</span></td>
        <td>${escapeHtml(from)}</td>
        <td>${escapeHtml(to)}</td>
        <td class="num">${fmtDateTime(n.createdAt)}</td>
        <td>${n.read ? badge("مقروء", "b-gray") : `<button class="mini mini--ok" data-read="${n.id}">تعليم كمقروء</button>`}</td>
      </tr>`;
    }).join("");

    const table = notifs.length ? `
      <div class="table-wrap"><table class="data">
        <thead><tr><th>النوع</th><th>الإشعار</th><th>من</th><th>إلى</th><th>الوقت</th><th></th></tr></thead>
        <tbody>${rows}</tbody>
      </table></div>` : emptyState("لا توجد إشعارات بعد", "🔔");

    const wrap = container.querySelector("#notif-list");
    if (!wrap) return;
    wrap.innerHTML = card(`سجل الإشعارات (${notifs.length})`, "🔔", table, "", "pad0");
    wrap.querySelectorAll("[data-read]").forEach((b) =>
      b.addEventListener("click", () => markNotificationRead(b.dataset.read).catch(() => {})));
  };

  // ربط زر الإرسال الفوري مرّة واحدة.
  container.querySelector("#n-send").onclick = async (e) => {
    const titleEl = container.querySelector("#n-title");
    const bodyEl = container.querySelector("#n-body");
    const title = titleEl.value.trim();
    const body = bodyEl.value.trim();
    if (!title && !body) return toast("اكتب عنواناً أو نصاً", "error");
    const btn = e.target;
    btn.disabled = true; btn.classList.add("is-loading");
    try {
      const n = await broadcastNotification({
        title, body, fromUid: user?.uid || "", fromName: user?.name || "مدير النظام",
      });
      toast(`أُرسل الإشعار إلى ${n} مستخدماً`, "success");
      titleEl.value = "";
      bodyEl.value = "";
    } catch (ex) {
      toast("تعذّر الإرسال: " + (ex.message || ex), "error");
    } finally {
      btn.disabled = false; btn.classList.remove("is-loading");
    }
  };

  const drawAll = () => { drawReminders(container); drawList(); };
  drawAll();
  return onStore(drawAll);
}

export default {
  title: "الإشعارات",
  sub: "البثّ الفوري والتنبيهات اليومية المجدولة",
  needs: ["notifications", "users", "scheduledReminders"],
  render,
};
