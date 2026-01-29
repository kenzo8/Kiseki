# Google 登录配置说明（Android 错误码 10）

若出现「Google 登录不可用」或 `ApiException: 10`（DEVELOPER_ERROR），通常是 **Android 应用的 SHA-1 未在 Firebase 中配置** 导致。按以下步骤操作即可修复。

## 1. 获取调试版 SHA-1（开发时使用）

在项目根目录执行。若提示「无法将 keytool 项识别为…」，说明未加入 PATH，请用下面带**完整路径**的命令。

**Windows (PowerShell)：**

若已配置 JAVA_HOME 或 keytool 在 PATH 中：
```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore"
```

若 keytool 未在 PATH 中，用 Android Studio 自带的（推荐）：
```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android
```

默认密码：`android`

**macOS / Linux：**
```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
```
默认密码：`android`

在输出中找到 **SHA1:** 和 **SHA256:**，复制这两行中的指纹（去掉冒号与空格，或直接整行复制均可）。

## 2. 在 Firebase 中添加指纹

1. 打开 [Firebase Console](https://console.firebase.google.com/)
2. 选择项目 **kiseki-34cd7**
3. 点击左侧 **项目设置**（齿轮图标）
4. 在「您的应用」中找到 **Android 应用**（包名 `com.example.kiseki`）
5. 若尚未添加 SHA，会看到「添加指纹」；若已有指纹，可点击 **添加指纹**
6. 分别粘贴 **SHA-1** 和 **SHA-256**，保存

## 3. 重新下载 google-services.json

1. 仍在 Firebase 项目设置 > 「您的应用」> 该 Android 应用
2. 点击 **下载 google-services.json**
3. 用下载的文件**替换**项目中的：
   - `android/app/google-services.json`

## 4. 确认 Firebase 已启用 Google 登录

1. Firebase Console > **Authentication（身份验证）** > **Sign-in method（登录方式）**
2. 找到 **Google**，确保状态为「已启用」

## 5. 清理并重新运行

```bash
flutter clean
flutter pub get
flutter run
```

## 发布版 / 正式包

若使用 **release** 或 **正式签名** 打包，需用**签名密钥**再次获取 SHA-1/SHA-256，并同样添加到 Firebase 中：

```bash
keytool -list -v -alias <你的别名> -keystore <你的.keystore或.jks路径>
```

在 Firebase 中为该 Android 应用再添加这一组指纹，并再次下载、替换 `google-services.json`。

---

完成以上步骤后，Google 登录应可正常使用。若仍有问题，请检查：

- 包名是否为 `com.example.kiseki`（与 Firebase 中一致）
- 是否已执行 `flutter clean` 并重新运行
