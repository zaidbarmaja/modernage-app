// ===============================================================
//  صفحة: إعدادات الشركة — موقع البصمة المعتمد + أوقات الدوام الموحّدة
//  يكتب في settings/company (مطابق لـ CompanySettings).
// ===============================================================

import { store, onStore } from "../store.js";
import { setCompanySettings } from "../data.js";
import { card, emptyState, badge } from "../ui.js";
import { minToHHMM, hhmmToMin, toast, escapeHtml, mapsUrl } from "../utils.js";

/** بطاقة (للقراءة فقط) بكل المواقع التي يستطيع الموظفون تسجيل الحضور منها:
 *  مقر الشركة (لموظفي التصميم) + كل موقع تنفيذ له إحداثيات (لموظفي التنفيذ). */
function locationsCard() {
  const s = store.data.settings || {};
  const sites = (store.data.sites || []).filter((st) => st.lat != null && st.lng != null);

  const row = (name, forWhom, kindBadge, lat, lng, radius) => `
    <tr>
      <td><b>${escapeHtml(name)}</b>${forWhom ? `<br><span class="muted">${escapeHtml(forWhom)}</span>` : ""}</td>
      <td>${kindBadge}</td>
      <td class="num">${radius ?? "—"} م</td>
      <td class="num">${(+lat).toFixed(5)}, ${(+lng).toFixed(5)}</td>
      <td><a class="mini mini--view" href="${mapsUrl(lat, lng)}" target="_blank" rel="noopener">📍 خريطة</a></td>
    </tr>`;

  const rows = [];
  if (s.lat != null && s.lng != null) {
    rows.push(row(s.name || "مقر الشركة", "يسجّل منه موظفو التصميم",
      badge("مقر الشركة", "b-olive"), s.lat, s.lng, s.radius ?? 150));
  }
  sites.forEach((st) => {
    const owner = st.ownerName ? `صاحب المشروع: ${st.ownerName}` : "";
    rows.push(row(st.siteName || st.ownerName || "موقع", owner,
      badge("موقع تنفيذ", "b-blue"), st.lat, st.lng, st.radius ?? 100));
  });

  const body = rows.length ? `
    <div class="table-wrap"><table class="data">
      <thead><tr><th>الموقع</th><th>النوع</th><th>النطاق</th><th>الإحداثيات</th><th></th></tr></thead>
      <tbody>${rows.join("")}</tbody>
    </table></div>`
    : emptyState("لم يُحدَّد أي موقع بعد. أضِف موقع الشركة أعلاه، أو أضِف مواقع تنفيذ بإحداثيات من صفحة «المشاريع والمواقع».", "📍");

  return card(`مواقع تسجيل الحضور (${rows.length})`, "📍", body, "", "pad0");
}

function render(container) {
  let dirty = false; // صار true بمجرّد أن يعدّل المستخدم أي حقل
  const draw = () => {
    const s = store.data.settings || {};

    container.innerHTML = card("إعدادات الشركة", "⚙️", `
      <div class="form-grid">
        <div class="field full">
          <label>اسم الشركة</label>
          <input id="s-name" value="${escapeHtml(s.name || "")}" placeholder="عصر الحداثة">
        </div>
        <div class="field">
          <label>خط العرض (Latitude)</label>
          <input id="s-lat" type="number" step="any" value="${s.lat ?? ""}" placeholder="مثال: 33.3152">
        </div>
        <div class="field">
          <label>خط الطول (Longitude)</label>
          <input id="s-lng" type="number" step="any" value="${s.lng ?? ""}" placeholder="مثال: 44.3661">
        </div>
        <div class="field">
          <label>نطاق السماح بالبصمة (متر)</label>
          <input id="s-radius" type="number" min="20" value="${s.radius ?? 150}">
        </div>
        <div class="field">
          <button class="btn btn--ghost" id="s-loc" type="button" style="align-self:flex-end">📍 التقاط موقعي الحالي</button>
        </div>
        <div class="field">
          <label>بداية الدوام</label>
          <input id="s-start" type="time" value="${minToHHMM(s.workStartMin ?? 8 * 60)}">
        </div>
        <div class="field">
          <label>نهاية الدوام</label>
          <input id="s-end" type="time" value="${minToHHMM(s.workEndMin ?? 16 * 60)}">
        </div>
      </div>
      <p class="hint">📌 يُستخدم موقع الشركة كنقطة بصمة معتمدة، وأوقات الدوام كقيمة افتراضية للموظفين بلا جدول مخصّص.</p>
      <div class="modal__actions" style="margin-top:16px">
        <button class="btn btn--primary" id="s-save">حفظ الإعدادات</button>
      </div>
    `) + locationsCard();

    const $ = (id) => container.querySelector(id);

    // أي تعديل يمنع إعادة الرسم التلقائي حتى لا يُمسح إدخال المستخدم.
    container.querySelectorAll("input").forEach((inp) =>
      inp.addEventListener("input", () => { dirty = true; }));

    $("#s-loc").onclick = () => {
      if (!navigator.geolocation) return toast("المتصفح لا يدعم تحديد الموقع", "error");
      toast("جارٍ تحديد الموقع…", "info");
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          $("#s-lat").value = pos.coords.latitude.toFixed(6);
          $("#s-lng").value = pos.coords.longitude.toFixed(6);
          toast("تم التقاط الموقع", "success");
        },
        () => toast("تعذّر تحديد الموقع (تأكّد من الإذن)", "error")
      );
    };

    $("#s-save").onclick = async (e) => {
      const btn = e.target;
      const lat = $("#s-lat").value.trim();
      const lng = $("#s-lng").value.trim();
      const data = {
        name: $("#s-name").value.trim(),
        lat: lat === "" ? null : Number(lat),
        lng: lng === "" ? null : Number(lng),
        radius: Number($("#s-radius").value) || 150,
        workStartMin: hhmmToMin($("#s-start").value) ?? 8 * 60,
        workEndMin: hhmmToMin($("#s-end").value) ?? 16 * 60,
      };
      btn.disabled = true; btn.classList.add("is-loading");
      try {
        await setCompanySettings(data);
        dirty = false;
        toast("تم حفظ الإعدادات", "success");
      } catch (ex) {
        toast("تعذّر الحفظ: " + (ex.message || ex), "error");
      } finally {
        btn.disabled = false; btn.classList.remove("is-loading");
      }
    };
  };

  draw();
  // نعيد الرسم عند وصول/تغيّر الإعدادات ما لم يكن المستخدم يعدّل.
  return onStore(() => { if (!dirty) draw(); });
}

export default {
  title: "إعدادات الشركة",
  sub: "موقع البصمة المعتمد وأوقات الدوام",
  needs: ["settings", "sites"],
  render,
};
