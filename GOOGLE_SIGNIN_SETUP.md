# Google 登录配置说明（Android 错误码 10）

若出现「Google 登录不可用」或 `ApiException: 10`（DEVELOPER_ERROR），通常是 **Android 应用的 SHA-1 未在 Firebase 中配置** 导致。按以下步骤操作即可修复。

**当前包名：`com.kenzo.kien`**

---

## 一、重新配置 Android Google 登录（完整流程）

### 1. 获取 SHA-1 和 SHA-256

在项目根目录或任意目录执行。若提示「无法将 keytool 项识别为…」，说明未加入 PATH，用下面带**完整路径**的命令。

**调试版（开发 / `flutter run` 使用）：**

**Windows (PowerShell)：**
```powershell
# 若 keytool 在 PATH 中：
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android

# 若未在 PATH，用 Android Studio 自带的（推荐）：
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android
```

**macOS / Linux：**
```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android
```

默认密码：`android`。在输出中找到 **SHA1:** 和 **SHA256:**，复制整行或指纹（可含冒号与空格）。

### 2. 在 Firebase 中添加指纹

1. 打开 [Firebase Console](https://console.firebase.google.com/)
2. 选择项目 **kiseki-34cd7**
3. 点击左侧 **项目设置**（齿轮图标）
4. 在「您的应用」中找到 **Android 应用**，包名 **`com.kenzo.kien`**
   - 若没有此应用：点击「添加应用」→ 选 Android → 包名填 `com.kenzo.kien` → 按提示完成添加
5. 在该 Android 应用下点击 **「添加指纹」**
6. 分别粘贴 **SHA-1** 和 **SHA-256**，保存

### 3. 重新下载并替换 google-services.json

1. 仍在 Firebase 项目设置 → 「您的应用」→ **com.kenzo.kien** 的 Android 应用
2. 点击 **「下载 google-services.json」**
3. 用下载的文件**替换**项目中的：`android/app/google-services.json`

**重要：** 必须用 Firebase 下载的这份文件。手动改包名而不添加 SHA 指纹，`google-services.json` 里不会有正确的 `certificate_hash`，Google 登录仍会报 10。

### 4. 确认已启用 Google 登录

1. Firebase Console → **Authentication（身份验证）** → **Sign-in method（登录方式）**
2. 找到 **Google**，确保状态为 **已启用**，并保存

### 5. 清理并重新运行

```bash
flutter clean
flutter pub get
flutter run
```

在真机上测试 **Continue with Google**，确认不再出现 `ApiException: 10`。

---

## 二、发布版 / 正式包

若使用 **release** 或 **正式签名** 打包，需用**发布用 keystore** 再获取一组 SHA-1/SHA-256：

```bash
keytool -list -v -alias <你的别名> -keystore <你的.keystore或.jks路径>
```

在 Firebase 中为 **com.kenzo.kien** 的 Android 应用**再添加**这一组指纹（调试版和发布版可同时存在），然后**再次下载并替换** `google-services.json`。

---

## 三、若仍有问题，请检查

- 包名是否为 **`com.kenzo.kien`**（与 `build.gradle.kts`、Firebase 中完全一致）
- 是否已执行 `flutter clean` 并重新 `flutter run`
- `android/app/google-services.json` 是否为 Firebase 下载的**最新**文件（包含你刚添加的指纹）
- Google 登录方式在 Firebase Auth 中是否已启用
