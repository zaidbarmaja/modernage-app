// ===============================================================
//  عصر الحداثة — طبقة الوصول لقاعدة بيانات Firestore
//  كل القراءة/الكتابة تمرّ من هنا. أسماء المجموعات والحقول مطابقة تماماً
//  لـ lib/core/constants.dart و lib/models/*.dart في تطبيق الجوال.
// ===============================================================

import {
  db, firebaseConfig, initializeApp, getApps, getApp, deleteApp,
  collection, doc, addDoc, setDoc, updateDoc, deleteDoc, getDoc, getDocs,
  onSnapshot, query, where, serverTimestamp, writeBatch, Timestamp,
  getAuth, createUserWithEmailAndPassword, updateProfile, signOut,
} from "./firebase.js";
import { loginKeys, idToEmail, makeCredential, newSalt, audienceMatches } from "./utils.js";

/** أسماء المجموعات — مطابقة لـ FsCollections في التطبيق. */
export const COL = {
  users: "users",
  attendance: "attendance",
  projects: "projects",            // مشاريع التصميم
  sites: "sites",                  // مواقع التنفيذ
  executionReports: "execution_reports",
  dailyReports: "daily_reports",
  siteCheckins: "site_checkins",
  expenses: "expenses",
  receipts: "receipts",
  notifications: "notifications",
  scheduledReminders: "scheduled_reminders", // تنبيهات الدوام اليومية المجدولة
  settings: "settings",
  credentials: "credentials",
  accountCustomers: "customers",   // زبائن نظام الحسابات (modage) — نفس مجموعة "customers"
};

/* --------------------------- الاشتراكات --------------------------- */

/** يشترك في مجموعة كاملة؛ يمرّر مصفوفة {id, ...data}. يُرجع دالة إلغاء. */
export function watch(colName, cb, onError) {
  return onSnapshot(
    collection(db, colName),
    (snap) => cb(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    (err) => { console.warn(`watch(${colName})`, err); onError?.(err); }
  );
}

/** يشترك في «الوصولات الإلكترونية» القادمة من نظام الحسابات (modage):
 *  حركات الزبائن حيث source='electronic'. تتضمّن صورة الوصل (imageUrl).
 *  تُقرأ لحظياً، فيظهر حذفها من الحسابات فوراً هنا (نُخفي المحذوف soft-deleted). */
export function watchElectronicReceipts(cb, onError) {
  return onSnapshot(
    query(collection(db, "customerTransactions"), where("source", "==", "electronic")),
    (snap) => cb(snap.docs.map((d) => ({ id: d.id, ...d.data() }))),
    (err) => { console.warn("watchElectronicReceipts", err); onError?.(err); }
  );
}

/** يشترك في مستند مفرد. */
export function watchDoc(colName, id, cb, onError) {
  return onSnapshot(
    doc(db, colName, id),
    (d) => cb(d.exists() ? { id: d.id, ...d.data() } : null),
    (err) => { console.warn(`watchDoc(${colName}/${id})`, err); onError?.(err); }
  );
}

/** جلب لمرة واحدة. */
export async function fetchAll(colName) {
  const snap = await getDocs(collection(db, colName));
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/* ---------------------------- الكتابة ---------------------------- */

export const addTo = (colName, data) =>
  addDoc(collection(db, colName), { createdAt: serverTimestamp(), ...data });

export const setAt = (colName, id, data, merge = false) =>
  setDoc(doc(db, colName, id), data, { merge });

export const updateAt = (colName, id, data) =>
  updateDoc(doc(db, colName, id), data);

export const removeAt = (colName, id) => deleteDoc(doc(db, colName, id));

/** طابع زمني من تاريخ JS للحقول من نوع date. */
export const ts = (date) => Timestamp.fromDate(date instanceof Date ? date : new Date(date));

/* --------------------- حذف متسلسل (Cascade) --------------------- */

/** حذف موقع تنفيذ مع كل تابعاته (وصولات/تقارير/صرفيات/تسجيلات دخول). */
export async function deleteSiteCascade(siteId) {
  const batch = writeBatch(db);
  batch.delete(doc(db, COL.sites, siteId));
  for (const c of [COL.receipts, COL.executionReports, COL.expenses, COL.siteCheckins]) {
    const snap = await getDocs(query(collection(db, c), where("siteId", "==", siteId)));
    snap.forEach((d) => batch.delete(d.ref));
  }
  await batch.commit();
}

/** حذف مشروع تصميم مع وصولاته وتقاريره، وفكّ ربط مواقعه. */
export async function deleteProjectCascade(projectId) {
  const batch = writeBatch(db);
  batch.delete(doc(db, COL.projects, projectId));
  for (const c of [COL.receipts, COL.dailyReports]) {
    const snap = await getDocs(query(collection(db, c), where("projectId", "==", projectId)));
    snap.forEach((d) => batch.delete(d.ref));
  }
  const sites = await getDocs(query(collection(db, COL.sites), where("projectId", "==", projectId)));
  sites.forEach((d) => batch.update(d.ref, { projectId: null }));
  await batch.commit();
}

/* --------------------------- المستخدمون --------------------------- */

/** حذف نهائي: ملف المستخدم + اعتماد كلمة المرور. */
export async function deleteUserPermanently(uid) {
  const batch = writeBatch(db);
  batch.delete(doc(db, COL.users, uid));
  batch.delete(doc(db, COL.credentials, uid));
  await batch.commit();
}

/** تغيير الدور/القسم/تصنيف التنفيذ (يُطبّع التصنيف لغير منفّذ التنفيذ). */
export const updateUserRole = (uid, role, department, workCategory = "general") =>
  updateAt(COL.users, uid, {
    role,
    department,
    workCategory: role === "executionEmployee" ? workCategory : "general",
  });

export const setUserActive = (uid, active) => updateAt(COL.users, uid, { active });

/** إعادة تعيين كلمة مرور حساب (اعتماد Firestore) وتفعيل مساره. */
export async function setUserPassword(uid, plain) {
  const cred = await makeCredential(uid, plain);
  const batch = writeBatch(db);
  batch.set(doc(db, COL.credentials, uid), cred);
  batch.update(doc(db, COL.users, uid), { useFirestorePassword: true });
  await batch.commit();
}

/* ---------------- إنشاء الحسابات (عبر تطبيق ثانوي) ---------------- */
//  يُنشئ حساب المصادقة عبر نسخة Firebase ثانوية كي لا يخرج المدير من جلسته،
//  ثم يكتب ملف المستخدم + الاعتماد عبر النسخة الأساسية (حيث المدير مصادَق).

const SECONDARY = "dashboardAccountCreator";

function secondaryAuth() {
  const app = getApps().some((a) => a.name === SECONDARY)
    ? getApp(SECONDARY)
    : initializeApp(firebaseConfig, SECONDARY);
  return { app, auth: getAuth(app) };
}

function uniqueEmail(loginId) {
  const base = idToEmail(loginId).split("@")[0];
  const r = () => Math.floor(Math.random() * 36).toString(36);
  return `${base}-${Array.from({ length: 8 }, r).join("")}@modernage.local`;
}

/**
 * إنشاء حساب (موظف/زبون). code = رمز الدخول الظاهر (٤ أرقام/نص) يُخزَّن كاعتماد.
 * يُرجع uid.
 */
async function createAccount({ name, loginId, code, role, department = "none",
  workCategory = "general", workStartMin = null, workEndMin = null,
  phone = "", contact = "" }) {
  const { app, auth } = secondaryAuth();
  try {
    let email = idToEmail(loginId);
    let cred;
    try {
      cred = await createUserWithEmailAndPassword(auth, email, newSalt());
    } catch (e) {
      if (e?.code !== "auth/email-already-in-use") throw e;
      email = uniqueEmail(loginId); // البريد الثابت محجوز من حساب محذوف
      cred = await createUserWithEmailAndPassword(auth, email, newSalt());
    }
    const uid = cred.user.uid;
    await updateProfile(cred.user, { displayName: name.trim() });

    // ملف المستخدم — يُكتب عبر النسخة الأساسية (المدير مصادَق) لتوافق القواعد.
    await setAt(COL.users, uid, {
      name: name.trim(),
      username: String(loginId).trim(),
      email,
      loginNames: loginKeys(loginId, phone),
      phone: String(phone).trim(),
      role,
      department,
      workCategory: role === "executionEmployee" ? workCategory : "general",
      workStartMin,
      workEndMin,
      contact: String(contact).trim(),
      active: true,
      useFirestorePassword: true,
      createdAt: serverTimestamp(),
    });
    const c = await makeCredential(uid, code);
    await setAt(COL.credentials, uid, c);
    return uid;
  } finally {
    try { await signOut(auth); } catch {}
    try { await deleteApp(app); } catch {}
  }
}

export const createEmployeeAccount = ({ name, username, password, role,
  department = "none", workCategory = "general", workStartMin = null,
  workEndMin = null, phone = "" }) =>
  createAccount({ name, loginId: username, code: password, role, department,
    workCategory, workStartMin, workEndMin, phone });

export const createCustomerAccount = ({ name, phone, accessCode, contact = "" }) =>
  createAccount({ name, loginId: phone, code: accessCode, role: "customer",
    department: "none", phone, contact });

/* --------------------------- الإشعارات --------------------------- */

/** بثّ إشعار للفئة المستهدفة [audience] (إشعار موجّه لكل uid مطابق). يُرجع العدد. */
export async function broadcastNotification({ title, body, fromUid, fromName, audience = "all" }) {
  const usersSnap = await getDocs(collection(db, COL.users));
  const batch = writeBatch(db);
  let count = 0;
  usersSnap.forEach((u) => {
    if (!audienceMatches(audience, u.data() || {})) return; // توجيه حسب الفئة
    const ref = doc(collection(db, COL.notifications));
    batch.set(ref, {
      type: "broadcast", title, body,
      fromUid: fromUid || "", fromName: fromName || "", toUid: u.id,
      // relatedId نصّ فارغ (لا null) لتوافق أوسع مع نموذج الإشعار في التطبيق.
      relatedId: "", lat: null, lng: null, read: false,
      createdAt: serverTimestamp(),
    });
    count++;
  });
  await batch.commit();
  return count;
}

export const markNotificationRead = (id) => updateAt(COL.notifications, id, { read: true });

/* -------------------- التنبيهات اليومية المجدولة -------------------- */
//  يقرأها التطبيق ويجدول إشعاراً محلياً على جهاز الموظف في وقت كل تنبيه.
//  minute = دقائق من منتصف الليل (10:00 صباحاً = 600).

export const addReminder = ({ title, body, minute, enabled = true, audience = "all" }) =>
  addTo(COL.scheduledReminders, { title, body, minute, enabled, audience });

export const updateReminder = (id, data) =>
  updateAt(COL.scheduledReminders, id, data);

export const deleteReminder = (id) => removeAt(COL.scheduledReminders, id);

/* ------------------------- إعدادات الشركة ------------------------- */

export const setCompanySettings = (data) =>
  setAt(COL.settings, "company", data, true);
