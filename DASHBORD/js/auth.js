// ===============================================================
//  عصر الحداثة — مصادقة لوحة التحكم
//  الدخول ببيانات ثابتة من config.js، مع جلسة Email/Password في الخلفية
//  (نفس الحساب الداخلي في التطبيق و modage) لتفعيل القراءة/الكتابة في Firestore.
// ===============================================================

import {
  auth, signInWithEmailAndPassword, createUserWithEmailAndPassword,
  signOut, setPersistence, browserLocalPersistence, browserSessionPersistence,
} from "./firebase.js";
import { APP_LOGIN } from "./config.js";

const AUTH_ERRORS = {
  "auth/operation-not-allowed":
    "فعّل «Email/Password» في Firebase: Authentication ← Sign-in method ← Email/Password ← Enable.",
  "auth/configuration-not-found":
    "المصادقة غير مهيّأة. فعّل Authentication في لوحة تحكم Firebase أولاً.",
  "auth/network-request-failed": "تعذّر الاتصال بالشبكة.",
};
const errMsg = (e) => AUTH_ERRORS[e?.code] || e?.message || "حدث خطأ غير متوقع.";

const SESSION_EMAIL = APP_LOGIN.authEmail || `${APP_LOGIN.username}@asr-app.com`;
const SESSION_PASS = APP_LOGIN.password;
const REMEMBER_KEY = "asr_dash_remember";

let sessionPromise = null;

/** جلسة Firebase الداخلية: دخول، وإنشاء الحساب أول مرة إن لزم. */
async function startSession() {
  try {
    await signInWithEmailAndPassword(auth, SESSION_EMAIL, SESSION_PASS);
  } catch (e) {
    const needsSignup =
      e?.code === "auth/user-not-found" ||
      e?.code === "auth/invalid-credential" ||
      e?.code === "auth/invalid-login-credentials";
    if (!needsSignup) throw e;
    try {
      await createUserWithEmailAndPassword(auth, SESSION_EMAIL, SESSION_PASS);
    } catch (e2) {
      throw e2?.code === "auth/email-already-in-use" ? e : e2;
    }
  }
}

export function ensureFirebaseSession() {
  if (!sessionPromise) {
    sessionPromise = startSession().catch((e) => { sessionPromise = null; throw e; });
  }
  return sessionPromise;
}

export function isRemembered() {
  try { return localStorage.getItem(REMEMBER_KEY) === "1"; } catch { return false; }
}
function setRemembered(on) {
  try {
    if (on) localStorage.setItem(REMEMBER_KEY, "1");
    else localStorage.removeItem(REMEMBER_KEY);
  } catch {}
}

/** يتحقّق من البيانات الثابتة ويؤسّس جلسة Firestore. يرمي عند الفشل. */
export async function login(username, password, remember) {
  if (username.trim() !== APP_LOGIN.username || password !== APP_LOGIN.password) {
    throw new Error("اسم المستخدم أو كلمة المرور غير صحيحة.");
  }
  try {
    await setPersistence(auth, remember ? browserLocalPersistence : browserSessionPersistence);
  } catch {}
  try {
    await ensureFirebaseSession();
  } catch (e) {
    throw new Error(errMsg(e));
  }
  setRemembered(!!remember);
  return {
    uid: auth.currentUser?.uid || "local",
    name: APP_LOGIN.displayName || APP_LOGIN.username,
    username: APP_LOGIN.username,
  };
}

/** دخول تلقائي عند تفعيل «تذكّرني». يُرجع بيانات المستخدم أو null. */
export async function tryAutoLogin() {
  if (!isRemembered()) return null;
  try {
    await ensureFirebaseSession();
    return {
      uid: auth.currentUser?.uid || "local",
      name: APP_LOGIN.displayName || APP_LOGIN.username,
      username: APP_LOGIN.username,
    };
  } catch (e) {
    console.warn("تعذّر الدخول التلقائي:", e?.message || e);
    return null;
  }
}

export async function logout() {
  setRemembered(false);
  sessionPromise = null;
  try { await signOut(auth); } catch {}
}

export { errMsg };
