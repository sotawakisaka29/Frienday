"use strict";

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");

initializeApp();

const region = "asia-northeast1";
const invalidTokenCodes = new Set([
  "messaging/invalid-registration-token",
  "messaging/registration-token-not-registered",
]);

/**
 * 新しい個人メッセージを、ブロックされていない相手の端末へ通知します。
 */
exports.sendDirectChatNotification = onDocumentCreated(
    {
      document: "directChats/{chatId}/messages/{messageId}",
      region,
      maxInstances: 10,
      retry: false,
    },
    async (event) => {
      const messageSnapshot = event.data;
      if (!messageSnapshot) {
        return;
      }

      const message = messageSnapshot.data();
      const chatId = event.params.chatId;
      const database = getFirestore();
      const chatSnapshot = await database.collection("directChats").doc(chatId).get();
      if (!chatSnapshot.exists) {
        return;
      }

      const participantIds = chatSnapshot.get("participantIds");
      if (!Array.isArray(participantIds) || participantIds.length !== 2) {
        logger.error("Invalid direct chat participants", {chatId});
        return;
      }

      const senderId = message.senderId;
      const recipientId = participantIds.find((userId) => userId !== senderId);
      if (!recipientId || typeof message.text !== "string") {
        return;
      }

      const recipientConnectionRef = database
          .collection("users")
          .doc(recipientId)
          .collection("connections")
          .doc(senderId);
      const [connectionSnapshot, senderBlockedSnapshot, recipientBlockedSnapshot] =
        await Promise.all([
          recipientConnectionRef.get(),
          database.collection("users").doc(senderId)
              .collection("blockedUsers").doc(recipientId).get(),
          database.collection("users").doc(recipientId)
              .collection("blockedUsers").doc(senderId).get(),
        ]);

      if (!connectionSnapshot.exists ||
          senderBlockedSnapshot.exists ||
          recipientBlockedSnapshot.exists) {
        return;
      }

      const activeGroupId = connectionSnapshot.get("activeGroupId");
      const [senderMemberSnapshot, recipientMemberSnapshot] = await Promise.all([
        database.collection("groups").doc(activeGroupId)
            .collection("members").doc(senderId).get(),
        database.collection("groups").doc(activeGroupId)
            .collection("members").doc(recipientId).get(),
      ]);
      if (!senderMemberSnapshot.exists || !recipientMemberSnapshot.exists) {
        return;
      }

      const [profileSnapshot, devicesSnapshot] = await Promise.all([
        database.collection("publicProfiles").doc(senderId).get(),
        database.collection("users").doc(recipientId)
            .collection("devices").get(),
      ]);
      const senderName = profileSnapshot.get("displayName") || "友達";
      const deviceDocuments = devicesSnapshot.docs.filter((document) => {
        const token = document.get("token");
        return typeof token === "string" && token.length > 0;
      });
      if (deviceDocuments.length === 0) {
        return;
      }

      for (let index = 0; index < deviceDocuments.length; index += 500) {
        const chunk = deviceDocuments.slice(index, index + 500);
        const tokens = chunk.map((document) => document.get("token"));
        const response = await getMessaging().sendEachForMulticast({
          tokens,
          notification: {
            title: senderName,
            body: message.text,
          },
          data: {
            type: "direct_chat",
            chatId,
            senderId,
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        });

        const invalidDeviceDeletes = [];
        response.responses.forEach((sendResponse, responseIndex) => {
          const code = sendResponse.error && sendResponse.error.code;
          if (!sendResponse.success && invalidTokenCodes.has(code)) {
            invalidDeviceDeletes.push(chunk[responseIndex].ref.delete());
          }
        });
        await Promise.all(invalidDeviceDeletes);
      }
    },
);

/**
 * 新しい通報を運営確認待ちにしてCloud Loggingへ記録します。
 */
exports.monitorChatReport = onDocumentCreated(
    {
      document: "reports/{reportId}",
      region,
      maxInstances: 5,
      retry: false,
    },
    async (event) => {
      const reportSnapshot = event.data;
      if (!reportSnapshot) {
        return;
      }

      const report = reportSnapshot.data();
      await reportSnapshot.ref.set(
          {
            reviewState: "unreviewed",
            queuedForReviewAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
      );

      logger.warn("CHAT_REPORT_REQUIRES_REVIEW", {
        reportId: event.params.reportId,
        chatId: report.chatId,
        messageId: report.messageId,
        reporterId: report.reporterId,
        reportedUserId: report.reportedUserId,
        reason: report.reason,
      });
    },
);
