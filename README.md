# MyGestures —— 我的 gestures（状态栏手势插件）

专为 **iPhone 12 Pro / iOS 16.6.1 / Relaxin（rootless 无根越狱）** 编写的状态栏手势插件。

## 功能

在**屏幕最顶部的状态栏区域**（时间、电量那一栏）做手势，**任何界面都有效**（包括锁屏界面、第三方 App 内）：

| 手势 | 默认动作 |
|---|---|
| 单击状态栏 | 无（默认关闭，避免误触） |
| 双击状态栏 | 锁屏 |
| 三击状态栏 | 截屏 |
| 状态栏左滑 | 手电筒开关 |
| 状态栏右滑 | 无（默认关闭） |

每个手势都可以在设置里换成：`无动作 / 锁屏 / 截屏 / 注销(Respring) / 手电筒开关`。

安装后到 **设置 → 我的手势** 里修改，改完立即生效，不用注销。

## 目录结构

```
手势插件/
├── Makefile              # Theos 构建脚本（rootless 打包）
├── control               # deb 包信息
├── Tweak.x               # ★核心源码：手势识别 + 动作执行
├── MyGestures.plist      # 注入过滤器（注入所有 UIKit 进程）
├── Prefs/
│   └── MyGestures.plist  # 设置面板（PreferenceLoader）
├── build.sh              # 一键编译脚本（WSL/Linux/Mac 用）
└── README.md             # 本文件
```

## 怎么编译出 deb

这台 Windows 电脑上没有装 WSL，无法直接编译 iOS 的 deb。两种办法任选：

### 方法一：装 WSL + Ubuntu（推荐，以后写插件都能用）

以管理员身份打开 PowerShell，执行（装完需要重启电脑一次）：

```powershell
wsl --install -d Ubuntu
```

重启后进入 Ubuntu 终端，执行：

```bash
cd /mnt/c/Users/10131/Desktop/我自己写的插件/手势插件
bash build.sh
```

`build.sh` 会自动装好 Theos（iOS 编译工具链 + SDK）并编译，产出的 deb 在 `packages/` 目录。

### 方法二：有 Mac 或 Linux 机器

把整个 `手势插件` 文件夹拷过去，同样执行：

```bash
bash build.sh
```

### 方法三：GitHub 云编译（不用装任何环境）

文件夹里已带 `.github/workflows/build.yml`：

1. 在 GitHub 建一个仓库（免费账号即可），把整个 `手势插件` 文件夹推上去；
2. 推送后 Actions 会自动开始编译；
3. 编译完成后，在仓库页面 **Actions → 最新一次运行 → Artifacts** 下载 `MyGestures-deb`，解压就是 deb。

### 手动编译（已经装好 Theos 的人）

```bash
export THEOS_PACKAGE_SCHEME=rootless
make package FINALPACKAGE=1
```

> ⚠️ 关键点：Relaxin 是 rootless 越狱，**必须**带 `THEOS_PACKAGE_SCHEME=rootless`，
> 打出来的 deb 才会安装到 `/var/jb` 下。不带这个参数编译出的 deb 装不上。

## 怎么安装

1. 把 `packages/` 里生成的 `com.local.mygestures_0.0.1_iphoneos-arm64.deb` 传到手机（AirDrop / 微信 / 网盘均可）。
2. 用 **Sileo**（Relaxin 自带）或 Filza 打开 deb → 安装 → 注销。
3. 到 **设置 → 我的手势** 按需调整手势。

## 工作原理（方便你自己改）

- 插件通过 `com.apple.UIKit` 过滤器注入所有带界面的进程，hook 了 `UIWindow` 的 `sendEvent:`，**只观察触摸、不拦截**，所以不影响系统原有操作（下拉通知中心、Safari 点状态栏回顶部等都正常）。
- 在 SpringBoard 进程里识别到手势 → 直接执行；在其它 App 里识别到 → 通过 **darwin 通知**转发给 SpringBoard 执行（截屏、锁屏这类系统动作只能在 SpringBoard 里做）。
- 手势判定参数都在 `Tweak.x` 顶部附近，改起来很直观：
  - 判定区域高度：`MGStatusZoneHeight()`（状态栏 + 12pt 容差）
  - 点击合并等待：`touchEnded:` 里的 `0.32` 秒
  - 滑动判定距离：`45.0` pt

## 想加新动作？

在 `Tweak.x` 里三步：

1. 写一个 `static void MGMyAction(void) { ... }`；
2. 在 `MGPerformInSpringBoard()` 里加一行 `else if ([action isEqualToString:@"myaction"]) MGMyAction();`
3. 在 `%ctor` 的观察数组 `@[@"lock", ...]` 里加上 `@"myaction"`；再在 `Prefs/MyGestures.plist` 的每个手势 `validValues`/`validTitles` 里各加一项。

## 排错

- **某个手势没反应**：先确认设置里绑定了动作；双击需两次点击间隔小于 0.32 秒。
- **锁屏/截屏无效**（不同系统版本私有 API 可能变动）：用电脑 console.app 或手机上的日志工具过滤 `MyGestures`，日志会写明走了哪条路径、失败在哪。锁屏有 `SBUIController lock` + `SBSLockDevice` 双保险，截屏有 `SBScreenShotter` 三种方法名自动尝试。
- **改了代码重新编译**：再跑一次 `bash build.sh` 即可。
- **想临时禁用**：设置里把手势全设为"无动作"即可，或卸载插件。

## 免责声明

仅用于自己的设备学习越狱插件开发，私有 API 调用（SBUIController、SBScreenShotter 等）在不同系统版本上可能变化，出问题卸载 deb 即可，不影响越狱本身。
