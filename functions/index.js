// ===============================================================
//  عصر الحداثة — Cloud Functions للإشعارات الفورية (Push / FCM)
//  عند إنشاء أي مستند في مجموعة notifications، تُرسل إشعاراً فورياً إلى أجهزة
//  المستخدم المستهدف (toUid) — يصل الهاتف والتطبيق مغلق مع صوت.
// ===============================================================

const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
setGlobalOptions({region: "us-central1", maxInstances: 10});

exports.pushOnNotification = onDocumentCreated(
    "notifications/{id}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;
      const n = snap.data() || {};
      const toUid = n.toUid;
      // إشعار إداري عام بلا مستلم محدّد → لا Push (يظهر داخل التطبيق فقط).
      if (!toUid) return;

      const db = getFirestore();
      const userDoc = await db.collection("users").doc(toUid).get();
      const tokens = ((userDoc.data() || {}).fcmTokens) || [];
      if (!tokens.length) return;

      const message = {
        notification: {
          title: n.title || "عصر الحداثة",
          body: n.body || "",
        },
        android: {
          priority: "high",
          notification: {channelId: "work_reminders", sound: "default"},
        },
        apns: {
          payload: {aps: {sound: "default"}},
        },
        tokens: tokens,
      };

      const res = await getMessaging().sendEachForMulticast(message);

      // إزالة الرموز غير الصالحة (أجهزة أُلغيت/حُذف التطبيق منها).
      const invalid = [];
      res.responses.forEach((r, i) => {
        if (!r.success) {
          const code = r.error && r.error.code;
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token" ||
            code === "messaging/invalid-argument"
          ) {
            invalid.push(tokens[i]);
          }
        }
      });
      if (invalid.length) {
        await db.collection("users").doc(toUid).update({
          fcmTokens: FieldValue.arrayRemove(...invalid),
        });
      }
    },
);
