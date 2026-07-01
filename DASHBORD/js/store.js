// ===============================================================
//  عصر الحداثة — مخزن البيانات المشترك (تحميل كسول lazy)
//  لا نشترك في كل المجموعات عند الإقلاع؛ بل تُشترَك كل مجموعة **عند الطلب**
//  (أوّل صفحة تحتاجها فقط)، ويبقى الاشتراك حيّاً حتى نهاية الجلسة فلا يُعاد
//  قراءتها عند العودة للصفحة. هذا + التخزين المحلي (IndexedDB) يقلّلان قراءات
//  Firestore (reads) لأدنى حدّ ممكن.
// ===============================================================

import { watch, watchDoc, watchElectronicReceipts, COL } from "./data.js";
import { toDate } from "./utils.js";

export const store = {
  data: {
    users: [], projects: [], sites: [], attendance: [],
    dailyReports: [], executionReports: [], receipts: [], expenses: [],
    siteCheckins: [], notifications: [], scheduledReminders: [], settings: {},
    accountCustomers: [],     // زبائن نظام الحسابات (modage)
    electronicReceipts: [],   // الوصولات الإلكترونية (customerTransactions/electronic)
  },
  _subs: new Set(),
  ready: false,
};

/** يسجّل مستمعاً يُستدعى عند أي تغيير في البيانات. يُرجع دالة إلغاء. */
export function onStore(cb) {
  store._subs.add(cb);
  return () => store._subs.delete(cb);
}

// تجميع التحديثات المتتالية في إطار عرض واحد بدل إعادة رسم كل الصفحات مع كل
// لقطة Firestore على حدة — أنعم بصرياً وأقل استهلاكاً.
let _emitScheduled = false;
function emit() {
  if (_emitScheduled) return;
  _emitScheduled = true;
  requestAnimationFrame(() => {
    _emitScheduled = false;
    for (const cb of store._subs) {
      try { cb(store.data); } catch (e) { console.error(e); }
    }
  });
}

const bySort = (field, dir = "desc") => (a, b) => {
  const av = toDate(a[field])?.getTime() ?? 0;
  const bv = toDate(b[field])?.getTime() ?? 0;
  return dir === "desc" ? bv - av : av - bv;
};
const byName = (a, b) => (a.name || "").localeCompare(b.name || "", "ar");

function set(key, rows) {
  store.data[key] = rows;
  store.ready = true;
  emit();
}

// مُنشئو الاشتراكات — لكل مجموعة دالة تبدأ اشتراكها لحظياً وتُرجع دالة الإلغاء.
const BINDERS = {
  users: () => watch(COL.users, (r) => set("users", r.sort(byName))),
  projects: () => watch(COL.projects, (r) => set("projects", r.sort(bySort("createdAt")))),
  sites: () => watch(COL.sites, (r) => set("sites", r.sort(bySort("createdAt")))),
  attendance: () => watch(COL.attendance, (r) => set("attendance", r.sort(bySort("checkIn")))),
  dailyReports: () => watch(COL.dailyReports, (r) => set("dailyReports", r.sort(bySort("date")))),
  executionReports: () => watch(COL.executionReports, (r) => set("executionReports", r.sort(bySort("date")))),
  receipts: () => watch(COL.receipts, (r) => set("receipts", r.sort(bySort("date")))),
  expenses: () => watch(COL.expenses, (r) => set("expenses", r.sort(bySort("date")))),
  siteCheckins: () => watch(COL.siteCheckins, (r) => set("siteCheckins", r.sort(bySort("time")))),
  notifications: () => watch(COL.notifications, (r) => set("notifications", r.sort(bySort("createdAt")))),
  scheduledReminders: () => watch(COL.scheduledReminders, (r) => set("scheduledReminders", r.sort((a, b) => (a.minute || 0) - (b.minute || 0)))),
  accountCustomers: () => watch(COL.accountCustomers, (r) => set("accountCustomers", r.sort(byName))),
  settings: () => watchDoc(COL.settings, "company", (d) => { store.data.settings = d || {}; emit(); }),
  electronicReceipts: () => watchElectronicReceipts((r) => set("electronicReceipts", r.sort(bySort("datetime")))),
};

// المجموعات المُشترَك فيها فعلاً (key → دالة الإلغاء).
const _active = new Map();

/**
 * يضمن اشتراك المجموعات المطلوبة (مرّة واحدة لكل مجموعة). تستدعيها كل صفحة
 * بما تحتاجه فقط، فلا تُقرأ مجموعة إلا إذا فُتحت صفحة تحتاجها.
 */
export function ensure(keys = []) {
  for (const k of keys) {
    if (_active.has(k)) continue;
    const binder = BINDERS[k];
    if (binder) _active.set(k, binder());
  }
}

/** يوقف كل الاشتراكات (عند الخروج). */
export function stopStore() {
  for (const unsub of _active.values()) { try { unsub(); } catch {} }
  _active.clear();
  store.ready = false;
}

/* ------------------------- مساعدات مشتقّة ------------------------- */

export const usersById = () => {
  const m = {};
  for (const u of store.data.users) m[u.id] = u;
  return m;
};

export const employees = () =>
  store.data.users.filter((u) => u.role === "designEmployee" || u.role === "executionEmployee");

export const customers = () => store.data.users.filter((u) => u.role === "customer");

/** زبائن نظام الحسابات الأصلي (مجموعة "customers" في modage) — {id, name}. */
export const accountCustomers = () => store.data.accountCustomers;

export const designers = () => store.data.users.filter((u) => u.role === "designEmployee");

export const executors = () => store.data.users.filter((u) => u.role === "executionEmployee");
