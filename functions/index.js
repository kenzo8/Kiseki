/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

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
