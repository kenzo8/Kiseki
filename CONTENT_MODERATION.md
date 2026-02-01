# Content Moderation (Google Play Compliance)

Device **name** and **note** are user-edited and stored in Firestore. To help pass Google Play review, a Firebase Cloud Function automatically sanitizes these fields on create and update.

## How It Works

- **Trigger**: Any create or update on the `seki` collection.
- **Action**: Replaces blocklisted words/phrases in `deviceName` and `note` with `***`.
- **Idempotent**: Only writes back when the sanitized text differs, so the trigger does not loop.

No client changes are required: the app keeps sending the same data; the function overwrites inappropriate content after the write.

## Extending the Blocklist

Edit `functions/index.js` and add entries to the `BLOCKLIST` array:

```js
const BLOCKLIST = [
  "fuck", "shit", "asshole", "damn", "crap", "wtf", "stfu",
  "hate", "kill", "die", "idiot", "dumb", "stupid",
  // Add more words/phrases (case-insensitive, whole-word match):
  // "your_word_here",
];
```

- Matching is **case-insensitive** and **whole-word** (e.g. "classic" is not replaced if "ass" is in the list).
- You can add locale-specific lists or later load blocklist from Firestore/Remote Config.

## Deploy the Function

From the project root:

```bash
cd functions
npm install
firebase deploy --only functions
```

Or deploy only this function:

```bash
firebase deploy --only functions:sanitizeSekiContent
```

## Testing

1. In the app, add or edit a device and set name or note to a blocklisted word.
2. In Firestore, the document should show `***` (or the replacement) for that field shortly after save.
3. Check logs: Firebase Console → Functions → sanitizeSekiContent → Logs.

## Troubleshooting

### "Permission denied while using the Eventarc Service Agent" / Validation failed for trigger

This often happens the **first time** you deploy a 2nd gen Firestore-triggered function. Two options:

1. **Wait and retry**: Wait 5–10 minutes, then run `firebase deploy --only functions` again. Google may need time to propagate Eventarc permissions.
2. **Grant Eventarc Service Agent in GCP**: Open [IAM](https://console.cloud.google.com/iam-admin/iam) for your project → find or add the member `service-PROJECT_NUMBER@gcp-sa-eventarc.iam.gserviceaccount.com` (use your project number from Firebase Project settings) → assign role **Eventarc Service Agent** → save, wait 1–2 minutes, then redeploy.

### Outdated `firebase-functions` warning

If the CLI suggests upgrading: in the `functions` folder run `npm install --save firebase-functions@latest`, then deploy again.

## Optional: Stricter or Multi-locale Lists

- Keep a larger blocklist in a separate JSON/JS file and require it in `index.js`.
- For multiple locales, you can add a `locale` field to `seki` (or derive from user profile) and choose different blocklists in the function.
