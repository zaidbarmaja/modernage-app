// ===============================================================
//  عصر الحداثة — لوحة تحكم مدير النظام
//  تهيئة Firebase (نقطة الاتصال الوحيدة بالـ SDK) — نفس مشروع التطبيق
//  (mohmeed-kadim) حتى تشترك اللوحة والتطبيق في نفس قاعدة البيانات.
// ===============================================================

import { initializeApp, getApps, getApp, deleteApp } from "https://www.gstatic.com/firebasejs/12.15.0/firebase-app.js";
import {
  getFirestore, initializeFirestore, persistentLocalCache, persistentMultipleTabManager,
  collection, collectionGroup, doc, addDoc, setDoc, updateDoc,
  deleteDoc, getDoc, getDocs, onSnapshot, query, where, orderBy, limit,
  serverTimestamp, writeBatch, Timestamp
} from "https://www.gstatic.com/firebasejs/12.15.0/firebase-firestore.js";
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, signOut, updateProfile, deleteUser,
  setPersistence, browserLocalPersistence, browserSessionPersistence
} from "https://www.gstatic.com/firebasejs/12.15.0/firebase-auth.js";
import {
  getStorage, ref as storageRef, uploadBytes, getDownloadURL
} from "https://www.gstatic.com/firebasejs/12.15.0/firebase-storage.js";

// إعدادات مشروع Firebase — مطابقة لـ lib/firebase_options.dart و modage.
export const firebaseConfig = {
  apiKey: "AIzaSyBZYqZneGS4mUeIENHfWb9Kz6OWl2p3zsc",
  authDomain: "mohmeed-kadim.firebaseapp.com",
  projectId: "mohmeed-kadim",
  storageBucket: "mohmeed-kadim.firebasestorage.app",
  messagingSenderId: "675551759018",
  appId: "1:675551759018:web:53d8cdd85d1874e48c9ed3"
};

export const app = initializeApp(firebaseConfig);

// تفعيل التخزين المؤقّت المحلي (IndexedDB): تُخدَّم القراءات المتكرّرة وإعادة
// التحميل من الذاكرة المحلية بلا تكلفة، ولا يُحاسَب Firestore إلا على المستندات
// الجديدة/المتغيّرة فعلاً — تقليل كبير لعدد القراءات (reads).
let _db;
try {
  _db = initializeFirestore(app, {
    localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }),
  });
} catch (_) {
  // إن سبق تهيئة Firestore أو تعذّر التخزين المحلي، نعود للوضع الافتراضي.
  _db = getFirestore(app);
}
export const db = _db;
export const auth = getAuth(app);
export const storage = getStorage(app);

// إعادة تصدير دوال الـ SDK لبقية الوحدات (مصدر واحد لنسخة الـ SDK).
export {
  initializeApp, getApps, getApp, deleteApp,
  collection, collectionGroup, doc, addDoc, setDoc, updateDoc, deleteDoc,
  getDoc, getDocs, onSnapshot, query, where, orderBy, limit,
  serverTimestamp, writeBatch, Timestamp,
  getAuth, onAuthStateChanged, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, signOut, updateProfile, deleteUser,
  setPersistence, browserLocalPersistence, browserSessionPersistence,
  storageRef, uploadBytes, getDownloadURL
};
