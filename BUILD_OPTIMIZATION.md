# App Size Optimization

This project enables Android R8 code shrinking and resource shrinking. You can further reduce app size with the Flutter build flags below.

## Enabled Optimizations (Android)

- **R8 code shrinking** (`isMinifyEnabled`): Remove unused code, obfuscate class/method names
- **Resource shrinking** (`isShrinkResources`): Remove unreferenced resources
- **ProGuard rules** (`android/app/proguard-rules.pro`): Keep Firebase, Google Sign In, Flutter plugins, etc.
- **Language resources** (`resConfigs("en", "zh", "ja")`): Keep only English, Chinese, and Japanese; drop other locales
- **ABI filtering** (arm only): Release builds include only `armeabi-v7a` and `arm64-v8a`; x86_64 is excluded (~10MB+ savings). x86 emulators cannot install release builds.

## Recommended Build Commands

### App Bundle (for Play Store, recommended)

```bash
flutter build appbundle --tree-shake-icons --split-debug-info=build/app/outputs/symbols --obfuscate
```

- `--tree-shake-icons`: Bundle only Material/Cupertino icons actually used
- `--split-debug-info`: Emit debug symbols to a separate directory; they are not included in the app
- `--obfuscate`: Obfuscate Dart code; slightly reduces size and hinders reverse engineering

### Split APKs by ABI (when distributing APKs directly)

```bash
flutter build apk --split-per-abi --tree-shake-icons --split-debug-info=build/app/outputs/symbols --obfuscate
```

This produces `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`, etc., each containing only that ABI (smaller than a fat APK).

### Universal APK (all architectures, larger)

```bash
flutter build apk --tree-shake-icons --split-debug-info=build/app/outputs/symbols --obfuscate
```

## Android Release Signing

Release builds use a **release keystore** when configured; otherwise they fall back to the debug keystore (not for Play Store upload).

**1. Generate a keystore** (once):

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**2. Configure `key.properties`:**

- Copy `android/key.properties.example` to `android/key.properties`
- Set `storePassword`, `keyPassword`, `keyAlias`, and `storeFile` (path to your `.jks` relative to `android/app/`, e.g. `../upload-keystore.jks`)

**3. Build:** Use the App Bundle or APK commands above. The release output will be signed with your keystore.

`key.properties` and `*.jks` are git-ignored. Never commit them. Add the release keystore’s **SHA-1/SHA-256** to Firebase (see [GOOGLE_SIGNIN_SETUP.md](GOOGLE_SIGNIN_SETUP.md)) for Google Sign-In to work in release builds.

## Debug Symbols & Crash Stack Traces

When using `--split-debug-info`, keep the `build/app/outputs/symbols` directory and use `dart symbolize` or Flutter’s symbolize workflow to deobfuscate release crash stack traces.

## Optional Optimizations

- **Assets**: Prefer WebP, appropriate resolutions, avoid redundant multi-density assets
- **Dependencies**: Run `flutter pub outdated`, remove unused packages, consider lighter alternatives
- **Fonts**: If using `fonts:`, include only the weights and styles you need

### Compress `assets/icon/app_icon.png`

It is 1024×1024 and ~**837 KB**, a large share of assets. Aim for **<200 KB**:

1. Compress with [TinyPNG](https://tinypng.com/) or [Squoosh](https://squoosh.app/), then overwrite the file
2. Keep 1024×1024 or 512×512 for `flutter_launcher_icons`
3. Re-run `flutter pub run flutter_launcher_icons` and `flutter build appbundle` (or your usual build)

---

## Why Is the Bundle Still This Big?

### Where the Size Comes From

- **Multi-architecture native libs** (`libflutter.so`, Firebase, Google Sign In, etc.): Flutter engine and plugins are built per ABI. After dropping x86_64, `arm64-v8a` and `armeabi-v7a` still account for much of the size.
- **BUNDLE-METADATA debug symbols** (~6MB): If the toolchain is incomplete, unstripped native debug symbols are bundled into the AAB. Fixing the toolchain and rebuilding reduces this.
- **Dart AOT + dependencies**: Packages like `excel`, `archive`, `xml` add to the Dart output. If you don’t need XLSX import/export, consider CSV-only and removing the `excel` dependency.
- **Assets**: `uses-material-design` is already optimized with `--tree-shake-icons`. Compress `assets/icon/app_icon.png` if it’s large (see above).

### What Do Users Actually Download?

You upload an **AAB**. Google Play serves **APKs** per device ABI, so users download only the package for their architecture (typically **15–25 MB**), not the full AAB.

### Effect of Current Optimizations

With `resConfigs("en", "zh", "ja")`, arm-only release builds, and R8/resource shrinking, the AAB went from ~**44 MB** to ~**31 MB**. You can reduce further by compressing `app_icon`, fixing the toolchain to strip debug symbols, or removing `excel` if unused.

---

## Fixing the Android Toolchain

If `flutter doctor` reports **cmdline-tools component is missing** or **Android license status unknown**, or the build fails with **"Failed to strip debug symbols from native libraries"**, fix the toolchain as follows.

### 1. Accept Android SDK Licenses

From the project root or any directory:

```bash
flutter doctor --android-licenses
```

Type `y` and Enter for each prompt until all are accepted.

### 2. Install Android SDK Command-line Tools

**Option A: Via Android Studio (recommended)**

1. Open Android Studio → **File** → **Settings** (Windows/Linux) or **Android Studio** → **Preferences** (macOS)
2. **Languages & Frameworks** → **Android SDK**
3. Open the **SDK Tools** tab
4. Check **Android SDK Command-line Tools (latest)**; if you need to strip native debug symbols, also ensure **NDK (Side by side)** is installed
5. Click **Apply** / **OK** and wait for installation

**Option B: Command-line tools only (no Android Studio)**

1. Open the [Android command-line tools page](https://developer.android.com/studio#command-line-tools-only), accept the terms, and download the **Windows** `commandlinetools-win-xxxxx_latest.zip`
2. Unzip to get a `cmdline-tools` directory with `bin`, `lib`, `NOTICE.txt`, `source.properties`, etc.
3. Create `cmdline-tools\latest` under your Android SDK root (usually `%LOCALAPPDATA%\Android\Sdk`, e.g. `C:\Users\<username>\AppData\Local\Android\Sdk`)
4. Move the **contents** of the unzipped `cmdline-tools` folder (not the folder itself) into `cmdline-tools\latest\`. The layout should look like:

   ```
   Android/Sdk/
   └── cmdline-tools/
       └── latest/
           ├── bin/
           ├── lib/
           ├── NOTICE.txt
           └── source.properties
   ```

5. If you use a proxy, temporarily disable it in `gradle.properties` or system settings before running `sdkmanager`, to avoid connection issues

### 3. Verify

```bash
flutter doctor -v
```

Confirm the **Android toolchain** has no `X` and no **cmdline-tools component is missing** or **Android license status unknown**. Then run:

```bash
flutter build appbundle
```

With a complete toolchain, you typically no longer see **"Failed to strip debug symbols from native libraries"**.

---

## FAQ

- **"Failed to strip debug symbols from native libraries"**: Usually due to an incomplete Android toolchain (e.g. missing cmdline-tools or NDK). The AAB is still produced and usable; only native debug symbols are not stripped. Fix the toolchain as above and rebuild to clear the warning.
