/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/v2/https");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ maxInstances: 10 });

// --- Handle migration for existing users ---
function generateHandleFromEmail(email) {
  const prefix = (email || "").split("@")[0].toLowerCase();
  const sanitized = prefix.replace(/[^a-z0-9_]/g, "");
  if (!sanitized) return "u";
  return sanitized.length > 12 ? sanitized.substring(0, 12) : sanitized;
}

async function ensureUniqueHandle(baseHandle, uid) {
  let candidate = baseHandle;
  const handleDoc = await db.collection("handles").doc(candidate).get();
  if (!handleDoc.exists) return candidate;
  const suffix = uid.length >= 5 ? uid.slice(-5) : uid;
  return `${baseHandle}_${suffix}`;
}

/**
 * HTTP: migrate existing users who lack a handle.
 * Run once via:
 *   Local:  curl "http://127.0.0.1:5001/kiseki-34cd7/us-central1/migrateHandles"
 *   Deploy: curl "https://us-central1-kiseki-34cd7.cloudfunctions.net/migrateHandles"
 */
exports.migrateHandles = onRequest(async (req, res) => {
  const usersSnap = await db.collection("users").get();
  const toMigrate = [];
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const handle = (data.handle || "").trim();
    if (!handle) {
      toMigrate.push({ uid: doc.id, email: (data.email || "").trim() });
    }
  }
  let migrated = 0;
  const batchMax = 500;
  let batch = db.batch();
  let opCount = 0;
  for (const { uid, email } of toMigrate) {
    const baseHandle = generateHandleFromEmail(email);
    const handle = await ensureUniqueHandle(baseHandle, uid);
    batch.update(db.collection("users").doc(uid), { handle });
    batch.set(db.collection("handles").doc(handle), { uid });
    opCount += 2;
    migrated++;
    if (opCount >= batchMax) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }
  if (opCount > 0) await batch.commit();
  logger.info("migrateHandles completed", { migrated, total: toMigrate.length });
  res.json({ migrated, total: toMigrate.length });
});

// --- Content sanitization for Google Play compliance ---
const REPLACEMENT = "***";

// Blocklist: words/phrases to replace (case-insensitive, whole-word match).
const BLOCKLIST = [
  // Profanity & common variants
  "fuck", "fck", "fuk", "fucking", "fucker", "fucked",
  "shit", "sh1t", "shitty", "bullshit",
  "asshole", "ass", "damn", "crap", "wtf", "stfu", "bs",
  "bitch", "b1tch", "b*tch", "bitches",
  "bastard", "dick", "cock", "cunt", "pussy", "slut", "whore",
  "piss", "pissed", "dumbass", "dipshit", "dumbshit",
  "motherfucker", "mf", "mofo",
  // Insults & put-downs
  "idiot", "dumb", "stupid", "retard", "retarded", "retards",
  "moron", "trash", "loser", "freak",
  // Hate & slurs (policy-relevant for store compliance)
  "nigger", "nigga", "niggas", "fag", "faggot", "faggots",
  "rape", "rapist", "pedo", "pedophile",
  // Violence / threats
  "kill", "killing", "murder", "die", "dying", "suicide",
  "hate", "hater", "terrorist", "bomb",
];

function sanitizeText(text) {
  if (typeof text !== "string" || text.trim() === "") return text;
  // Escape special regex chars in blocklist and match whole words only
  const escaped = BLOCKLIST.map((w) => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
  const re = new RegExp(`\\b(${escaped.join("|")})\\b`, "gi");
  return text.replace(re, REPLACEMENT);
}

/**
 * On create/update of a "seki" doc, sanitize deviceName and note;
 * update only if changed (avoids infinite trigger loop).
 */
exports.sanitizeSekiContent = onDocumentWritten("seki/{docId}", (event) => {
  const after = event.data?.after;
  if (!after || !after.exists) return;
  const data = after.data();
  if (!data) return;

  const name = typeof data.deviceName === "string" ? data.deviceName : "";
  const note = typeof (data.note ?? "") === "string" ? (data.note ?? "") : "";

  const sanitizedName = sanitizeText(name);
  const sanitizedNote = sanitizeText(note);

  if (sanitizedName === name && sanitizedNote === note) return;

  const updates = {};
  if (sanitizedName !== name) updates.deviceName = sanitizedName;
  if (sanitizedNote !== note) updates.note = sanitizedNote;

  logger.info("Sanitizing seki content", { docId: event.params.docId, fieldsUpdated: Object.keys(updates) });
  return after.ref.update(updates);
});
