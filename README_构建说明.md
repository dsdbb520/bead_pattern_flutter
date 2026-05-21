# 拼豆图纸生成器 Flutter 版 — 构建说明

## 第一步：安装 Flutter
见主 README：下载 SDK，加入 PATH，安装 Android Studio 和 Visual Studio C++ 工作负载。

## 第二步：创建项目骨架
在本目录外执行：
```
flutter create bead_pattern_flutter --platforms android,windows
```
然后把本目录中的所有文件 **覆盖** 进刚创建的 bead_pattern_flutter 目录。

## 第三步：修改 Android 权限
打开 android/app/src/main/AndroidManifest.xml，在 <application> 标签 **之前** 加入：
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

## 第四步：安装依赖并运行
```
flutter pub get

# Windows 桌面
flutter run -d windows

# Android（先连接手机，开启 USB 调试）
flutter run -d android

# 打包
flutter build windows    # 生成 build/windows/runner/Release/
flutter build apk        # 生成 build/app/outputs/flutter-apk/app-release.apk
```

## 文件说明
| 文件 | 说明 |
|------|------|
| lib/main.dart | 程序入口 |
| lib/palette.dart | 144 种拼豆颜色 + 精细度档位 |
| lib/processor.dart | 图片处理 + LAB 颜色匹配（在独立线程运行） |
| lib/app_state.dart | 全局状态管理 + 导出功能 |
| lib/bead_canvas.dart | 可缩放画布 + 高亮 |
| lib/settings_panel.dart | 设置面板（桌面固定 / 手机底部抽屉）|
| lib/home_page.dart | 自适应布局（宽屏桌面 / 窄屏手机）|
