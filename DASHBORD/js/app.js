// ===============================================================
//  عصر الحداثة — نقطة الدخول والموجّه (Router) للوحة التحكم
// ===============================================================

import { ensureFirebaseSession } from "./auth.js";
import { APP_LOGIN } from "./config.js";
import { ensure, store, onStore } from "./store.js";
import { $, $$, toast } from "./utils.js";

import overview from "./pages/overview.js";
import projects from "./pages/projects.js";
import reports from "./pages/reports.js";
import attendance from "./pages/attendance.js";
import finance from "./pages/finance.js";
import users from "./pages/users.js";
import notifications from "./pages/notifications.js";
import settings from "./pages/settings.js";

const PAGES = { overview, projects, reports, attendance, finance, users, notifications, settings };

let currentCleanup = null;
let currentUser = null;

/* --------------------------- دخول اللوحة --------------------------- */
//  لا توجد شاشة تسجيل دخول — تُعرَض اللوحة مباشرة (انظر boot).

function enterApp(user) {
  currentUser = user;
  $("#login-screen").hidden = true;
  $("#app").hidden = false;
  $("#side-user-name").textContent = user.name;
  wireNav();
  wireChrome();
  wireNotifDot();
}

function wireNav() {
  $$("#nav .nav__item").forEach((btn) => {
    btn.addEventListener("click", () => {
      navigate(btn.dataset.page);
      closeSidebar();
    });
  });
}

function wireChrome() {
  $("#topbar-notif").addEventListener("click", () => navigate("notifications"));
  const toggle = $("#menu-toggle");
  const sidebar = $("#sidebar");
  const backdrop = $("#sidebar-backdrop");
  toggle?.addEventListener("click", () => {
    sidebar.classList.toggle("open");
    backdrop.classList.toggle("show");
  });
  backdrop?.addEventListener("click", closeSidebar);
}

function closeSidebar() {
  $("#sidebar")?.classList.remove("open");
  $("#sidebar-backdrop")?.classList.remove("show");
}

/* شارة عدد الإشعارات الإدارية غير المقروءة (الموجّهة للإدارة: toUid فارغ). */
function wireNotifDot() {
  onStore((data) => {
    const unread = data.notifications.filter(
      (n) => (!n.toUid || n.toUid === "") && !n.read
    ).length;
    const dot = $("#notif-dot");
    const badge = document.querySelector('.nav__item[data-page="notifications"] .badge')
      || (() => {
        const b = document.createElement("span");
        b.className = "badge";
        document.querySelector('.nav__item[data-page="notifications"]').appendChild(b);
        return b;
      })();
    if (unread > 0) {
      dot.hidden = false; dot.textContent = unread > 99 ? "99+" : unread;
      badge.hidden = false; badge.textContent = unread > 99 ? "99+" : unread;
    } else {
      dot.hidden = true; badge.hidden = true;
    }
  });
}

/* ----------------------------- التنقّل ----------------------------- */

function navigate(name) {
  const page = PAGES[name] || PAGES.overview;
  name = PAGES[name] ? name : "overview";
  location.hash = name;

  // تنظيف الصفحة السابقة (إلغاء اشتراكاتها).
  if (typeof currentCleanup === "function") { try { currentCleanup(); } catch {} }
  currentCleanup = null;

  $$("#nav .nav__item").forEach((b) => b.classList.toggle("active", b.dataset.page === name));
  $("#page-title").textContent = page.title;
  $("#page-sub").textContent = page.sub;

  // تحميل كسول: نشترك فقط في المجموعات التي تحتاجها هذه الصفحة (تقليل القراءات).
  ensure(page.needs || []);

  const container = $("#page");
  container.innerHTML = "";
  currentCleanup = page.render(container, { user: currentUser }) || null;

  // مؤثّر دخول ناعم متتابع عند فتح الصفحة. يُزال بعد انتهائه كي لا يتكرّر
  // مع التحديث اللحظي للبيانات (onStore يعيد بناء المحتوى دون تنقّل).
  container.classList.remove("intro");
  void container.offsetWidth;            // إعادة تشغيل الأنيميشن
  container.classList.add("intro");
  clearTimeout(navigate._introT);
  navigate._introT = setTimeout(() => container.classList.remove("intro"), 950);

  container.scrollIntoView?.({ block: "start" });
}

/* ----------------------------- الإقلاع ----------------------------- */

async function boot() {
  // بلا شاشة تسجيل دخول — تُفتح اللوحة مباشرة، وتُؤسَّس جلسة Firestore في الخلفية
  // (لازمة للقراءة/الكتابة حسب قواعد الأمان) قبل بدء الاشتراك في البيانات.
  enterApp({
    uid: "local",
    name: APP_LOGIN.displayName || "مدير النظام",
    username: APP_LOGIN.username,
  });
  $("#page").innerHTML = '<div class="loading">جارٍ تجهيز اللوحة…</div>';
  try {
    await ensureFirebaseSession();
  } catch (e) {
    toast("تعذّر الاتصال بقاعدة البيانات — تحقّق من اتصال الإنترنت", "error", 4500);
  }
  // لا نُحمّل كل المجموعات هنا؛ كل صفحة تطلب ما تحتاجه عبر ensure(page.needs).
  navigate(location.hash.replace("#", "") || "overview");
}

window.addEventListener("hashchange", () => {
  if (!$("#app").hidden) {
    const name = location.hash.replace("#", "") || "overview";
    if (PAGES[name]) navigate(name);
  }
});

boot();
