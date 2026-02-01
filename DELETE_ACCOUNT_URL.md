# Delete Account URL (Google Play)

Google Play requires a **Delete account URL** that is shown on your store listing. This project provides a hosted page that meets the requirements.

## What was added

1. **Firebase Hosting** in `firebase.json` – serves static files from the `public/` folder.
2. **`public/delete-account.html`** – a standalone page that:
   - Refers to the app name **Kien** (as on the store listing).
   - Prominently lists the steps users take to request account deletion (in-app).
   - Specifies what data is deleted and that there is no additional retention period.

## Deploy and get the URL

1. Deploy hosting (from the project root):

   ```bash
   firebase deploy --only hosting
   ```

2. After deploy, Firebase will print your hosting URL, e.g.:
   - `https://kiseki-34cd7.web.app`
   - or `https://kiseki-34cd7.firebaseapp.com`

3. Your **Delete account URL** is:
   - **`https://kiseki-34cd7.web.app/delete-account.html`**  
   (Replace `kiseki-34cd7` with your project ID if different.)

## Add the URL in Google Play Console

1. Open [Google Play Console](https://play.google.com/console) → your app.
2. Go to **Policy** → **App content** (or **App content** in the left menu).
3. Find **Data safety** / **Delete account** (or the section that asks for “Delete account URL”).
4. Paste the URL:  
   `https://<your-project-id>.web.app/delete-account.html`

## First-time Firebase Hosting

If you have not used Hosting before:

- The first `firebase deploy --only hosting` may ask you to confirm creating a hosting site. Say yes.
- You can set a custom domain later in Firebase Console → Hosting if you want a different URL.

## Editing the page

- Edit `public/delete-account.html` to change app name, steps, or data/retention text.
- Redeploy with `firebase deploy --only hosting` so the store listing link stays up to date.
