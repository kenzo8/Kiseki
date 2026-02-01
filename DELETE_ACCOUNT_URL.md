# Delete Account URL & Delete Data URL (Google Play)

Google Play can ask for two links on your store listing:

1. **Delete account URL** – link for users to request that their **account and associated data** is deleted.
2. **Delete data URL** – link for users to request that **some or all of their data** is deleted **without** deleting their account.

This project provides hosted pages for both.

## What was added

1. **Firebase Hosting** in `firebase.json` – serves static files from the `public/` folder.
2. **`public/delete-account.html`** – for **Delete account URL**:
   - Refers to the app name **Kien** (as on the store listing).
   - Steps to request account deletion (in-app).
   - What data is deleted and no additional retention.
3. **`public/delete-data.html`** – for **Delete data URL**:
   - Refers to the app name **Kien**.
   - Steps to request data deletion without deleting account (delete devices, remove wishlist items; optional link to account deletion).
   - Types of data deleted or kept and no additional retention.

## Deploy and get the URLs

1. Deploy hosting (from the project root):

   ```bash
   firebase deploy --only hosting
   ```

2. After deploy, use these URLs (replace `kiseki-34cd7` with your project ID if different):

   | Field in Play Console | URL |
   |------------------------|-----|
   | **Delete account URL** | `https://kiseki-34cd7.web.app/delete-account.html` |
   | **Delete data URL**    | `https://kiseki-34cd7.web.app/delete-data.html`   |

## Add the URLs in Google Play Console

1. Open [Google Play Console](https://play.google.com/console) → your app.
2. Go to **Policy** → **App content** (or **App content** in the left menu).
3. **Delete account URL:** Find the “Delete account URL” field (under Data safety / account deletion). Paste:  
   `https://<your-project-id>.web.app/delete-account.html`
4. **Delete data URL:** In the question “Do you provide a way for users to request that some or all of their data is deleted, without requiring them to delete their account?” select **Yes**, then in “Delete data URL” paste:  
   `https://<your-project-id>.web.app/delete-data.html`

## First-time Firebase Hosting

If you have not used Hosting before:

- The first `firebase deploy --only hosting` may ask you to confirm creating a hosting site. Say yes.
- You can set a custom domain later in Firebase Console → Hosting if you want a different URL.

## Editing the pages

- **Account deletion:** edit `public/delete-account.html`.
- **Data deletion (without account):** edit `public/delete-data.html`.
- Redeploy with `firebase deploy --only hosting` so the store listing links stay up to date.
