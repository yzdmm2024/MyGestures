# MyGestures —— 我的手势（状态栏左右耳朵手势）

适配 **iPhone X–16**（自动区分刘海屏、灵动岛），专为 **iOS 16.x rootless 越狱（Relaxin/Dopamine 系）** 编写。
v0.1.0 按产品需求大改：只识别状态栏左右"耳朵"，刘海/灵动岛本体触摸直接忽略。

## 怎么用

### 1. 打开设置面板

**设置 → 我的手势**（标题显示「我的手势 0.1.0」确认装上新版）。面板顶部有示意图：
🟢绿色框 = 左右耳朵（可操作），🔴红色框 = 刘海/灵动岛（触摸忽略）。

### 2. 支持的手势（仅三个）

| 手势 | 说明 | 出厂默认 |
|---|---|---|
| 单击耳朵 | 快速点一下 | 无（关闭） |
| 双击耳朵 | 间隔 <0.32s 连点两下，**必须同一只耳朵**，跨耳不计 | **锁屏** |
| 左滑耳朵 | 贴着顶边向左横滑，Y 轴偏移过大自动过滤 | **手电筒开关** |

长按、三击、上滑、**下滑全部交给系统**：本插件不接管下拉手势，向下滑动事件完整透传，
通知中心、控制中心不受任何影响，**可与各类控制中心越狱插件共存**。

### 3. 两大模式（开关：启用状态栏左右分区）

- **关闭（默认）**：左右耳朵共用一套 单击/双击/左滑 配置；
- **开启**：左段（时间侧）与右段（电池信号侧）完全独立配置，互不干扰。

### 4. 动作选项

无 / 锁屏 / 截屏 / 手电筒开关 / Respring注销 / 返回主屏幕 / 打开本工具设置面板（仅单击可用）。
选「无」= 单独禁用该手势，无需关闭整个插件；全部设「无」时插件静默驻留。

### 5. 全局设置

- **锁屏界面启用手势**：关闭后锁屏界面全部手势失效，App 内不受影响；
- **手势震动反馈**：手势执行成功震动；
- **双击识别间隔**：0.20s–0.50s 滑块，默认 0.32s；
- **App黑名单**：子页面列出全部已装 App，开关加入黑名单，名单内 App 全部手势失效。

> 所有设置修改**即时生效，不需要 Respring**。

### 6. 屏幕区域规则（自动适配，不硬编码机型）

读取 `safeAreaInsets` 判断：顶部插入量 ≥45pt = 刘海/灵动岛机型，左右各 38% 为耳朵、
中间 24% 遮挡矩形丢弃触摸；否则左右各 50%。

## 兼容性

- ✅ 与所有控制中心类越狱插件共存（事件只观察不拦截）；
- ✅ 下拉通知中心/控制中心、Safari 点状态栏回顶部等原生行为不受影响；
- ✅ rootless（Relaxin/Dopamine）适配；设置面板照「系统-设置出现面板菜单的方法」方案（arm64+arm64e 双切片、显式链接 Preferences）。

## 目录结构

```
手势插件/
├── Makefile                          # tweak + 面板 bundle 双目标构建
├── control                           # deb 信息（0.1.0）
├── Tweak.x                           # ★耳朵分区判定 + 手势识别 + 动作执行
├── MyGestures.plist                  # 注入过滤器（项目根目录）
├── Preferences/
│   ├── MGSettingsController.m        # 面板主控制器（示意图/条件显隐/全局项）
│   └── MGBlacklistController.m       # App 黑名单子页面（枚举已装应用）
├── layout/
│   ├── DEBIAN/preinst|postinst       # 安装脚本
│   └── Library/…/MyGesturesPrefs.bundle(Info|Root) + PreferenceLoader 入口
├── .github/workflows/build.yml       # CI 云编译
└── README.md
```

## 发布流程（全自动）

```bash
git push（或 git data API）→ CI 自动编译 → gh run download -n MyGestures-deb
```

验货清单：deb 内 data.tar 6 文件（/var/jb 前缀）、bundle 可执行 arm64+arm64e 双切片、
链接 Preferences.framework、面板版本号与 control 一致。

## 偏好键位表（调试用）

- 模式：`splitMode`；全局：`lockScreenEnabled` `hapticsEnabled` `tapInterval`
- 不分段：`singleTap` `doubleTap` `swipeLeft`
- 分段：`left_singleTap` `left_doubleTap` `left_swipeLeft` `right_*` 同理
- 黑名单：`bl_<bundleid>`（bool）
- suite：`com.local.mygestures`；全部即时生效

## 排错

- **设置里没有入口**：entry 的 `bundle` 字段必须 = `MyGesturesPrefs`（坑C）；
- **点开报「已损坏或丢失必要的资源」**：arm64e 切片（坑F）或 Preferences 链接（坑E）；
- **手势没反应**：确认触摸点在耳朵区域（不在刘海/岛上）；确认该 App 不在黑名单；锁屏全局开关是否打开；
- 日志过滤 `MyGestures`。
