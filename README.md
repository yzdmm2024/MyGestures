# MyGestures —— 我的手势（状态栏手势插件）

专为 **iPhone 12 Pro / iOS 16.6.1 / Relaxin（rootless 无根越狱）** 编写的状态栏手势插件。
v0.0.2 起设置面板改用 PreferenceBundle + PSListController 方案（照
`系统-设置出现面板菜单的方法` 实战文档，已修全部 7 个坑）。

## 怎么用（装好后看这里）

### 1. 打开设置面板

> **设置 → 我的手势**（就在「设置」主列表里，和"通用""辅助功能"并列）

标题显示 **「我的手势 0.0.2」** —— 凭版本号确认装上新版。装完 deb 后需注销一次（安装包会自动注销）。

### 2. 面板里能设置什么

5 个手势各自可绑定一个动作，点进去选即可，**改完立即生效，不用注销**：

| 手势 | 怎么做 | 默认动作 |
|---|---|---|
| 单击状态栏 | 在屏幕最顶上点一下 | 无（默认关，防误触） |
| 双击状态栏 | 快速连点两下（间隔 < 0.32 秒） | **锁屏** |
| 三击状态栏 | 快速连点三下 | **截屏** |
| 状态栏左滑 | 贴着顶边向左横滑 | **手电筒开关** |
| 状态栏右滑 | 贴着顶边向右横滑 | 无 |

动作可选：`无动作 / 锁屏 / 截屏 / 注销（Respring） / 手电筒开关`。

### 3. 在哪做手势

**屏幕最顶部的状态栏**（时间、电量那一小条，约 60pt 高），**任何界面都有效**——
主界面、锁屏后、微信 Safari 等任意 App 里都可以。

### 4. 不影响正常操作

插件只"偷看"触摸、不拦截：下拉通知中心、下拉搜索、点状态栏回顶部（Safari/微信）等都和原来一样。

## 目录结构

```
手势插件/
├── Makefile                          # tweak + 面板 bundle 双目标构建（含坑E/F/G修复）
├── control                           # deb 信息（0.0.2）
├── Tweak.x                           # ★手势识别 + 动作执行（CFPreferences 读设置）
├── MyGestures.plist                  # 注入过滤器（项目根目录，坑A）
├── Preferences/MGSettingsController.m# 面板主控制器（PSListController）
├── layout/
│   ├── DEBIAN/preinst|postinst       # 安装脚本（清理旧入口 / 自动注销）
│   └── Library/
│       ├── PreferenceLoader/Preferences/MyGesturesPrefs.plist   # 设置入口（坑C）
│       └── PreferenceBundles/MyGesturesPrefs.bundle/
│           ├── Info.plist            # 面板包描述（坑D）
│           └── Root.plist            # 面板内容（标题带版本号）
├── .github/workflows/build.yml       # CI 云编译（macos + 14.5 SDK）
└── README.md
```

## 改代码后的发布流程（全自动）

```bash
git add -A && git commit -m "xxx" && git push     # 云端自动编译
gh run watch                                       # 看构建
gh run download -n MyGestures-deb -D packages_ci   # 下载 deb
```

CI 绿后照例验货：deb 里 data.tar 应有 6 个文件
（dylib + filter + 入口 plist + bundle 的 Info/Root/可执行），bundle 可执行是 arm64+arm64e 双切片。

## 排错（对应实战文档的症状表）

- **设置里完全没有入口**：入口层问题 → 查 entry 的 `bundle` 字段是否 = `MyGesturesPrefs`（坑C）、preinst 是否清了旧入口。
- **入口在，点开报「已损坏或丢失必要的资源」**：面板层问题 → 基本是 arm64e 切片（坑F）或没链接 Preferences.framework（坑E）。
- **手势没反应**：确认面板里绑定了动作；双击间隔要 < 0.32 秒；确认触摸点在状态栏区域内。
- 日志过滤关键字 `MyGestures`。

## 免责声明

仅用于自己设备学习越狱插件开发。私有 API（SBUIController、SBScreenShotter 等）随系统版本可能变化，异常时卸载 deb 即可。
