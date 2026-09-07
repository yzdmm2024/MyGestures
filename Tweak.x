/**
 * MyGestures v0.1.0 —— 状态栏左右"耳朵"手势 (rootless)
 *
 * 适用环境: iPhone X–16 / iOS 16.x / Relaxin (Dopamine 系 rootless 越狱)
 * 构建: Theos, THEOS_PACKAGE_SCHEME=rootless
 *
 * 核心规则:
 *   - 只识别状态栏左右"耳朵"区域; 刘海/灵动岛本体矩形内的触摸一律忽略, 不响应手势
 *   - 仅支持: 单击 / 双击 / 左滑; 长按、三击、上滑、下滑全部交给系统原生处理
 *   - 事件只观察不拦截 (%orig 永远先走), 下拉通知中心/控制中心完整透传,
 *     可与各类控制中心越狱插件共存
 *   - 双击: 两次点击必须落在同一个耳朵区域, 跨耳朵点击不计双击
 *
 * 模式:
 *   不分段(默认): 左右耳朵共用 singleTap / doubleTap / swipeLeft 三个键
 *   分段:        left_* / right_* 六个键, 左段时间侧、右段电池信号侧独立
 *
 * 动作: none/lock/screenshot/flashlight/respring/home/settingspanel
 *       (settingspanel 仅单击可用; 面板已限制)
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreHaptics/CoreHaptics.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <math.h>

#define MGLog(fmt, ...) NSLog(@"[MyGestures] %@", [NSString stringWithFormat:fmt, ##__VA_ARGS__])

/* ========================= 偏好设置 ========================= */

static NSString *const kSuite        = @"com.local.mygestures";
static NSString *const kNotifyPrefix = @"com.local.mygestures.";

// SBCameraHardwareButton 单例引用 (秒开相机用)
static id gCameraButtonInstance = nil;

// 偏好内存缓存 (v0.7.1 性能修复):
// 旧实现每次触摸都同步等待 cfprefsd (跨进程往返), 全系统每一次触摸都被卡一下;
// 现改为内存缓存: 面板改动经 CFPreferences 变更通知立即失效缓存, 另有 2 秒 TTL 兜底
static NSMutableDictionary *mgPrefCache = nil;
static CFTimeInterval mgPrefLastFetch = 0;

// 14.5 SDK 的 tbd 未导出 CFPreferencesAddObserver, 运行时 dlsym 获取
static void (*mgPrefsAddObs)(CFStringRef, void *, void (*)(void *, CFStringRef, void *), CFStringRef, void *) = NULL;

static void MGPrefChangeCB(void *observer, CFStringRef key, void *context)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (mgPrefCache) [mgPrefCache removeAllObjects]; // 偏好被(面板)修改 → 缓存立即失效
    });
}

static id MGPrefValue(NSString *key)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        mgPrefCache = [NSMutableDictionary new];
        void *h = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY);
        if (h) mgPrefsAddObs = (void (*)(CFStringRef, void *, void (*)(void *, CFStringRef, void *), CFStringRef, void *))dlsym(h, "CFPreferencesAddObserver");
        if (mgPrefsAddObs) mgPrefsAddObs((__bridge CFStringRef)kSuite, NULL, MGPrefChangeCB, NULL, NULL);
    });
    CFTimeInterval now = CACurrentMediaTime();
    if (now - mgPrefLastFetch > 2.0) { // TTL 兜底: 通知万一漏掉, 设置改动最多延迟 2 秒生效
        [mgPrefCache removeAllObjects];
        mgPrefLastFetch = now;
    }
    id cached = mgPrefCache[key];
    if (cached) return [cached isEqual:NSNull.null] ? nil : cached;
    CFTypeRef raw = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kSuite);
    id val = raw ? CFBridgingRelease(raw) : (id)NSNull.null;
    mgPrefCache[key] = val;
    return [val isEqual:NSNull.null] ? nil : val;
}

static NSString *MGPrefString(NSString *key)
{
    id v = MGPrefValue(key);
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

static BOOL MGPrefBool(NSString *key, BOOL def)
{
    id v = MGPrefValue(key);
    return [v isKindOfClass:[NSNumber class]] ? [v boolValue] : def;
}

static CGFloat MGPrefFloat(NSString *key, CGFloat def)
{
    id v = MGPrefValue(key);
    return [v isKindOfClass:[NSNumber class]] ? [v doubleValue] : def;
}

static BOOL MGActionEnabled(NSString *action)
{
    return action.length > 0 && ![action isEqualToString:@"none"];
}

/* ===================== 耳朵区域判定 ===================== */

typedef NS_ENUM(NSInteger, MGEar) {
    MGEarNone  = 0, // 状态栏区域外 / 刘海·灵动岛本体 → 直接忽略
    MGEarLeft  = 1, // 左耳朵 (时间侧)
    MGEarRight = 2, // 右耳朵 (信号/Wi-Fi/电池侧)
};

/*
 * 判定依据 (不硬编码机型):
 *   safeAreaInsets.top >= 45 → 刘海/灵动岛机型 (X-13 约 44~48, 灵动岛 54~59),
 *                              中间 24% 宽的遮挡矩形不响应手势, 左右 38% 各为一只耳朵
 *   否则                     → 非遮挡机型, 左右各 50% (X-16 全是遮挡机型, 此分支兜底)
 */
static MGEar MGEarForPoint(UIWindow *w, CGPoint p)
{
    CGFloat top = w.safeAreaInsets.top;
    CGFloat zoneH = (top >= 20.0 ? top : 20.0) + 10.0; // 状态栏高度 + 10pt 容差
    if (p.y < 0.0 || p.y > zoneH) return MGEarNone;

    CGFloat bw = w.bounds.size.width;
    if (top >= 45.0) { // 刘海 / 灵动岛机型
        if (p.x < bw * 0.38) return MGEarLeft;
        if (p.x > bw * 0.62) return MGEarRight;
        return MGEarNone; // 🔴 刘海/灵动岛本体 → 触摸丢弃
    }
    return (p.x < bw * 0.5) ? MGEarLeft : MGEarRight;
}

/* ===================== 手势 → 动作键 ===================== */

static NSString *MGEarName(MGEar ear)
{
    return (ear == MGEarRight) ? @"right" : @"left";
}

static NSString *MGDefaultActionForKey(NSString *key)
{
    if ([key hasSuffix:@"doubleTap"] || [key isEqualToString:@"doubleTap"]) return @"lock";
    if ([key hasSuffix:@"swipeLeft"]  || [key isEqualToString:@"swipeLeft"])  return @"flashlight";
    return @"none"; // 单击默认关, 防误触
}

// 分段模式: left_doubleTap 这类键; 不分段: doubleTap
static NSString *MGActionForGesture(MGEar ear, NSString *gesture)
{
    NSString *key;
    if (MGPrefBool(@"splitMode", NO) && ear != MGEarNone)
        key = [NSString stringWithFormat:@"%@_%@", MGEarName(ear), gesture];
    else
        key = gesture;

    NSString *v = MGPrefString(key);
    return (v.length > 0) ? v : MGDefaultActionForKey(key);
}

/* ============== 动作执行 (只能在 SpringBoard 进程内做) ============== */

static BOOL MGIsSpringBoard(void)
{
    static BOOL isSB = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        isSB = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
    });
    return isSB;
}

static BOOL MGUILocked(void)
{
    Class c = objc_getClass("SBLockScreenManager");
    if (!c) return NO;
    id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
    if (!inst || ![inst respondsToSelector:@selector(isUILocked)]) return NO;
    return ((BOOL (*)(id, SEL))objc_msgSend)(inst, @selector(isUILocked));
}

static void MGLockScreen(void)
{
    Class c = objc_getClass("SBUIController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        SEL lockSel = sel_registerName("lock");
        if (inst && [inst respondsToSelector:lockSel]) {
            ((void (*)(id, SEL))objc_msgSend)(inst, lockSel);
            MGLog(@"锁屏成功 (SBUIController lock)");
            return;
        }
    }
    void *h = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    if (h) {
        void (*lockDev)(void) = (void (*)(void))dlsym(h, "SBSLockDevice");
        if (lockDev) { lockDev(); MGLog(@"锁屏成功 (SBSLockDevice)"); return; }
    }
    MGLog(@"锁屏失败: 未找到可用方法");
}

// 截屏: iOS 16.6 的 SBScreenShotter 已不存在 (frida 反射实锤),
// 改用系统截图器 SSScreenCapturer - takeScreenshot (无参, 走完整系统截屏流程)
static void MGScreenshot(void)
{
    Class c = objc_getClass("SSScreenCapturer");
    if (c) {
        id inst = nil;
        SEL si = sel_registerName("sharedInstance");
        if ([c respondsToSelector:si])
            inst = ((id (*)(id, SEL))objc_msgSend)(c, si);
        if (!inst) {
            id a = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("alloc"));
            inst = ((id (*)(id, SEL))objc_msgSend)(a, sel_registerName("init"));
        }
        SEL ts = sel_registerName("takeScreenshot");
        if (inst && [inst respondsToSelector:ts]) {
            ((void (*)(id, SEL))objc_msgSend)(inst, ts);
            MGLog(@"截屏成功 (SSScreenCapturer takeScreenshot)");
            return;
        }
    }
    MGLog(@"截屏失败: SSScreenCapturer 不可用");
}

static void MGToggleFlashlight(void)
{
    AVCaptureDevice *dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!dev || !dev.hasTorch) { MGLog(@"手电筒失败: 无闪光灯设备"); return; }
    NSError *err = nil;
    if ([dev lockForConfiguration:&err]) {
        dev.torchMode = (dev.torchMode == AVCaptureTorchModeOn) ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
        [dev unlockForConfiguration];
        MGLog(@"手电筒已切换 -> %ld", (long)dev.torchMode);
    } else {
        MGLog(@"手电筒失败: %@", err.localizedDescription);
    }
}

static void MGRespring(void)
{
    MGLog(@"注销 (respring)…");
    exit(0);
}

// 返回主屏幕: 16.6 无 simulateHomeButtonClick, 用 handleHomeButtonSinglePressUpForWindowScene:
static void MGGoHome(void)
{
    Class c = objc_getClass("SBUIController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        if (inst) {
            id scene = nil;
            @try {
                id app = ((id (*)(id, SEL))objc_msgSend)(objc_getClass("UIApplication"), sel_registerName("sharedApplication"));
                id scenes = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("connectedScenes"));
                scene = ((id (*)(id, SEL))objc_msgSend)(scenes, sel_registerName("anyObject"));
            } @catch (NSException *e) {}
            SEL h1 = sel_registerName("handleHomeButtonSinglePressUpForWindowScene:");
            if ([inst respondsToSelector:h1]) {
                ((void (*)(id, SEL, id))objc_msgSend)(inst, h1, scene);
                MGLog(@"返回主屏幕 (handleHomeButtonSinglePressUpForWindowScene:)");
                return;
            }
            SEL h2 = sel_registerName("handleHomeButtonSinglePressUpForWindowScene:withSourceType:");
            if ([inst respondsToSelector:h2]) {
                ((void (*)(id, SEL, id, long long))objc_msgSend)(inst, h2, scene, 0);
                MGLog(@"返回主屏幕 (handleHomeButtonSinglePressUpForWindowScene:withSourceType:)");
                return;
            }
        }
    }
    MGLog(@"返回主屏幕失败: SBUIController 方法不可用");
}

static void MGOpenURLString(NSString *urlString); // 前置声明(实现在媒体区)

// 打开设置面板: 直接走已验证安全的 openURL 通路 (prefs: 页面深链不中时也会打开设置根页)
static void MGOpenPrefsPanel(void)
{
    MGOpenURLString(@"prefs:root=MyGesturesPrefs");
}

/* ===== 控制中心类动作 (全部带多类/多选择器兜底, 找不到就记日志放弃) ===== */

// 通用布尔开关: 遍历候选类/读选择器取当前值, 用第一个可用的写选择器翻转
static void MGToggleSetting(NSArray *classNames, NSArray *getters, NSArray *setters, NSString *label)
{
    for (NSString *cn in classNames) {
        Class c = objc_getClass(cn.UTF8String);
        if (!c) continue;
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        if (!inst) continue;

        BOOL cur = NO;
        BOOL haveCur = NO;
        for (NSString *g in getters) {
            SEL gs = NSSelectorFromString(g);
            if ([inst respondsToSelector:gs]) {
                cur = ((BOOL (*)(id, SEL))objc_msgSend)(inst, gs);
                haveCur = YES;
                break;
            }
        }
        for (NSString *sn in setters) {
            SEL ss = NSSelectorFromString(sn);
            if ([inst respondsToSelector:ss]) {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(inst, ss, !cur);
                MGLog(@"%@ 成功 (%@ %@, 原值=%d)", label, cn, sn, haveCur ? cur : -1);
                return;
            }
        }
    }
    MGLog(@"%@ 失败: 没有可用的类/选择器", label);
}

// 无参方法: 执行第一个可用的
static void MGInvokeFirst(NSArray *classNames, NSArray *sels, NSString *label)
{
    for (NSString *cn in classNames) {
        Class c = objc_getClass(cn.UTF8String);
        if (!c) continue;
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        if (!inst) continue;
        for (NSString *sn in sels) {
            SEL s = NSSelectorFromString(sn);
            if ([inst respondsToSelector:s]) {
                ((void (*)(id, SEL))objc_msgSend)(inst, s);
                MGLog(@"%@ 成功 (%@ %@)", label, cn, sn);
                return;
            }
        }
    }
    MGLog(@"%@ 失败: 没有可用的类/选择器", label);
}

// WiFi 开关: WiFiKit WFControlCenterStateMonitor performAction: (控制中心同款动作, 真机实测调用成功)
static void MGToggleWiFi(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit", RTLD_LAZY);
    });
    Class c = objc_getClass("WFControlCenterStateMonitor");
    if (c) {
        id mon = ((id (*)(id, SEL))objc_msgSend)([c alloc], sel_registerName("init"));
        if (mon) {
            ((void (*)(id, SEL, id))objc_msgSend)(mon, sel_registerName("performAction:"), nil);
            MGLog(@"WiFi开关 成功 (WFControlCenterStateMonitor performAction)");
            return;
        }
    }
    // 兜底: SBWiFiManager
    MGToggleSetting(@[@"SBWiFiManager"],
                    @[@"wifiEnabled", @"isWiFiEnabled"],
                    @[@"setWiFiEnabled:", @"setWiFiPowered:"],
                    @"WiFi开关");
}

// 蓝牙开关: BluetoothManager bluetoothStateActionWithCompletion: (真机实测状态真实切换 3→2)
static void MGToggleBluetooth(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_LAZY);
    });
    Class c = objc_getClass("BluetoothManager");
    if (c) {
        id bm = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        if (bm) {
            SEL s1 = sel_registerName("bluetoothStateActionWithCompletion:");
            if ([bm respondsToSelector:s1]) {
                ((void (*)(id, SEL, id))objc_msgSend)(bm, s1, nil);
                MGLog(@"蓝牙开关 成功 (bluetoothStateActionWithCompletion:)");
                return;
            }
            SEL s2 = sel_registerName("bluetoothStateAction");
            if ([bm respondsToSelector:s2]) {
                ((void (*)(id, SEL))objc_msgSend)(bm, s2);
                MGLog(@"蓝牙开关 成功 (bluetoothStateAction)");
                return;
            }
        }
    }
    MGToggleSetting(@[@"SBBluetoothManager", @"SBBluetoothPowerController"],
                    @[@"bluetoothEnabled", @"isBluetoothEnabled", @"enabled"],
                    @[@"setBluetoothEnabled:", @"setEnabled:"],
                    @"蓝牙开关");
}

static void MGToggleAirplane(void)
{
    MGToggleSetting(@[@"SBTelephonyManager", @"SBAirplaneModeManager"],
                    @[@"airplaneMode", @"isInAirplaneMode"],
                    @[@"setAirplaneMode:"],
                    @"飞行模式");
}

static void MGToggleLowPower(void)
{
    MGToggleSetting(@[@"SBLowPowerModeManager", @"SBBatteryManager"],
                    @[@"lowPowerMode", @"isLowPowerModeEnabled", @"lowPowerModeEnabled"],
                    @[@"setLowPowerMode:", @"setLowPowerModeEnabled:"],
                    @"低电量模式");
}

// 媒体命令: MediaRemote (SB 进程内确认存在); 命令值: 2=播放暂停 4=下一首 5=上一首
static void MGMediaCommand(int cmd, NSString *label)
{
    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (h) {
        void (*fn)(int, id) = (void (*)(int, id))dlsym(h, "MRMediaRemoteSendCommand");
        if (fn) {
            fn(cmd, nil);
            MGLog(@"%@ 成功 (MRMediaRemoteSendCommand %d)", label, cmd);
            return;
        }
    }
    MGLog(@"%@ 失败: MediaRemote 不可用", label);
}

static void MGTogglePlayPause(void)
{
    Class c = objc_getClass("SBMediaController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        SEL s = sel_registerName("togglePlayPauseForEventSource:"); // 16.6 实测存在
        if (inst && [inst respondsToSelector:s]) {
            ((void (*)(id, SEL, id))objc_msgSend)(inst, s, nil);
            MGLog(@"播放/暂停 成功 (SBMediaController togglePlayPauseForEventSource:)");
            return;
        }
    }
    MGMediaCommand(2, @"播放/暂停");
}

static void MGNextTrack(void)
{
    MGMediaCommand(4, @"下一首");
}

static void MGPrevTrack(void)
{
    MGMediaCommand(5, @"上一首");
}

/* ===== 0.2.0 新增: 音量 / App切换器 / 链接系统 ===== */

// 音量步进 (AVSystemController, 16.6 实测可调用)
static void MGVolumeBy(float delta)
{
    Class c = objc_getClass("AVSystemController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedAVSystemController"));
        SEL s = sel_registerName("changeActiveCategoryVolumeBy:");
        if (inst && [inst respondsToSelector:s]) {
            @try {
                ((BOOL (*)(id, SEL, float))objc_msgSend)(inst, s, delta);
                MGLog(@"音量步进 %f", delta);
                return;
            } @catch (NSException *e) { MGLog(@"音量异常: %@", e); }
        }
    }
    MGLog(@"音量失败: AVSystemController 不可用");
}

static void MGVolUp(void)   { MGVolumeBy(0.0625); }
static void MGVolDown(void) { MGVolumeBy(-0.0625); }

// 静音: 媒体音量归零 (经典 setVolumeTo:forCategory: 路径)
static void MGMute(void)
{
    Class c = objc_getClass("AVSystemController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedAVSystemController"));
        if (inst) {
            NSString *cat = @"Audio/Video";
            SEL s1 = sel_registerName("setVolumeTo:forCategory:");
            if ([inst respondsToSelector:s1]) {
                ((BOOL (*)(id, SEL, float, id))objc_msgSend)(inst, s1, 0.0, cat);
                MGLog(@"静音成功 (setVolumeTo:forCategory:)");
                return;
            }
            SEL s2 = sel_registerName("setVolume:forCategory:");
            if ([inst respondsToSelector:s2]) {
                ((BOOL (*)(id, SEL, float, id))objc_msgSend)(inst, s2, 0.0, cat);
                MGLog(@"静音成功 (setVolume:forCategory:)");
                return;
            }
        }
    }
    MGLog(@"静音失败: AVSystemController 不可用");
}

// App 切换器: 双击 Home 的内部方法 (16.6 实测存在)
static void MGAppSwitcher(void)
{
    Class c = objc_getClass("SBUIController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        SEL s = sel_registerName("handleHomeButtonDoublePressDown");
        if (inst && [inst respondsToSelector:s]) {
            ((void (*)(id, SEL))objc_msgSend)(inst, s);
            MGLog(@"App切换器 成功 (handleHomeButtonDoublePressDown)");
            return;
        }
    }
    MGLog(@"App切换器失败: SBUIController 不可用");
}

// 0.5.0: 相机 (真实启动相机App) / 无线局域网设置页 / 蜂窝网络开关
static void MGDispatchAction(NSString *action); // 前置声明(run 回环用)

// 按 bundle id 真实启动 App: SBSLaunchApplicationWithIdentifier
// (网上资料 + 真机实测: 不崩, 真实打开 —— 本项目 App 打开的最终解)
static BOOL MGLaunchApp(NSString *bid)
{
    static void (*sbsLaunch)(CFStringRef, int) = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (h) sbsLaunch = (void (*)(CFStringRef, int))dlsym(h, "SBSLaunchApplicationWithIdentifier");
    });
    if (!sbsLaunch || bid.length == 0) return NO;
    sbsLaunch((__bridge CFStringRef)bid, 0);
    return YES;
}

// 打开控制中心: SBControlCenterController presentAnimated:completion:
// (开源插件 ShakeItOff 同款写法, iOS 16.3 运行时头文件确认 API 存在; 控制中心里点相机是系统预热秒开)
// 超级截图 (SN3 延伸板 v5.8+ 自带 darwin 触发口, 与控制中心按钮同一通知):
// 拉起遮罩框选截图 → 框选后出现 OCR/翻译/长截图/问AI 菜单
// 前提: 手机装有 超级截图(SN3延伸板) 并启用; 未装时无人响应, 不会崩
static void MGTriggerSN3(void)
{
    if (!MGPrefBool(@"sn3Enabled", YES)) {
        MGLog(@"超级截图已禁用 (sn3Enabled=NO)");
        return;
    }
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.axs.snapper3zhext.cc.capture"),
        NULL, NULL, TRUE);
    MGLog(@"超级截图 触发 (SN3 cc.capture)");
}

// 秒开相机: SBCameraHardwareButton._launchCameraIfReady
// 和物理相机按钮/控制中心相机同一预热路径, 真正秒开
static void MGCameraOpen(void)
{
    if (gCameraButtonInstance) {
        @try {
            MGLog(@"相机秒开 (SBCameraHardwareButton._launchCameraIfReady)");
            ((void (*)(id, SEL))objc_msgSend)(gCameraButtonInstance, sel_registerName("_launchCameraIfReady"));
            return;
        } @catch (NSException *e) {
            MGLog(@"相机秒开异常: %@", e);
        }
    }
    // 兜底: 走 SBUIController 冷启动
    @try {
        Class appCtl = objc_getClass("SBApplicationController");
        Class uiCtl = objc_getClass("SBUIController");
        if (!appCtl || !uiCtl) { MGLog(@"相机失败: 类不存在"); return; }
        id app = ((id (*)(id, SEL, id))objc_msgSend)(
            ((id (*)(id, SEL))objc_msgSend)((id)appCtl, sel_registerName("sharedInstance")),
            sel_registerName("applicationWithBundleIdentifier:"),
            @"com.apple.camera");
        if (!app) { MGLog(@"相机失败: 找不到 Camera App"); return; }
        ((void (*)(id, SEL, id, id, id, id, id))objc_msgSend)(
            ((id (*)(id, SEL))objc_msgSend)((id)uiCtl, sel_registerName("sharedInstance")),
            sel_registerName("activateApplication:fromIcon:location:activationSettings:actions:"),
            app, NULL, NULL, NULL, NULL);
        MGLog(@"相机启动 (SBUIController 兜底)");
    } @catch (NSException *e) {
        MGLog(@"相机异常: %@", e);
    }
}

static void MGOpenControlCenter(void)
{
    @try {
        Class c = objc_getClass("SBControlCenterController");
        if (!c) { MGLog(@"控制中心失败: 类不存在"); return; }
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        SEL vis = sel_registerName("isVisible");
        SEL pres = sel_registerName("presentAnimated:completion:");
        if (inst && [inst respondsToSelector:vis] && [inst respondsToSelector:pres]) {
            BOOL visible = ((BOOL (*)(id, SEL))objc_msgSend)(inst, vis);
            if (!visible) {
                ((void (*)(id, SEL, BOOL, id))objc_msgSend)(inst, pres, YES, nil);
                MGLog(@"控制中心 成功 (presentAnimated)");
            } else {
                MGLog(@"控制中心已打开, 忽略");
            }
            return;
        }
        MGLog(@"控制中心失败: API 不可用");
    } @catch (NSException *e) {
        MGLog(@"控制中心异常: %@", e);
    }
}
static void MGOpenWLAN(void)     { MGOpenURLString(@"prefs:root=WIFI"); }
static void MGToggleCellular(void)
{
    Class c = objc_getClass("SBTelephonyManager");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedInstance"));
        SEL g = sel_registerName("isCellDataSwitchingEnabled");
        SEL s = sel_registerName("setCellDataSwitchingEnabled:");
        if (inst && [inst respondsToSelector:g] && [inst respondsToSelector:s]) {
            BOOL cur = ((BOOL (*)(id, SEL))objc_msgSend)(inst, g);
            ((void (*)(id, SEL, BOOL))objc_msgSend)(inst, s, !cur);
            MGLog(@"蜂窝网络开关 成功 (原值=%d)", cur);
            return;
        }
    }
    MGOpenURLString(@"prefs:root=MOBILE_DATA_SETTINGS_ID");
}

// 打开指定 App: SBS 真实启动; 失败回退 scheme 表
static void MGOpenAppByID(NSString *bid)
{
    if (MGLaunchApp(bid)) {
        MGLog(@"打开应用成功 (SBSLaunchApplicationWithIdentifier %@)", bid);
        return;
    }
    NSDictionary *map = @{
        @"com.tencent.xin":          @"weixin://",        // 微信
        @"com.tencent.mqq":          @"mqq://",           // QQ
        @"com.alipay.iphoneclient":  @"alipay://",        // 支付宝
        @"com.taobao.taobao4iphone": @"taobao://",        // 淘宝
        @"com.xunmeng.pinduoduo":    @"pinduoduo://",     // 拼多多
        @"com.ss.iphone.ugc.Aweme":  @"snssdk1128://",    // 抖音
        @"com.smile.gifmaker":       @"kwai://",          // 快手
        @"com.sina.weibo":           @"sinaweibo://",     // 微博
        @"com.netease.cloudmusic":   @"orpheus://",       // 网易云音乐
        @"com.baidu.BaiduMobile":    @"BaiduSSO://",      // 百度
        @"com.autonavi.minimap":     @"iosamap://",       // 高德地图
        @"com.jingdong.app.mall":    @"openapp.jdmobile://", // 京东
    };
    NSString *scheme = map[bid];
    if (scheme.length > 0) { MGOpenURLString(scheme); return; }
    MGLog(@"打开应用失败: 「%@」暂无内置通路, 可在快捷指令建「打开App」后经 我的链接 绑定", bid);
}

// 从 SpringBoard 打开 URL
// 16.6 唯一可用通路 (frida 钩子实测请求真实到达 SB 总入口):
//   dlopen SpringBoardServices → SBSOpenSensitiveURL (老 SBSOpenSensitiveURLWithOptions 的改名版)
//   (FBSSystemService openURL 是静默哑火, 勿用)
static void MGOpenURLString(NSString *urlString)
{
    if (urlString.length == 0) { MGLog(@"打开链接失败: 空地址"); return; }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url || !url.scheme)
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:urlString]]; // 裸域名兜底
    if (!url) { MGLog(@"打开链接失败: 无效地址 %@", urlString); return; }
    static void (*sbsOpen)(CFURLRef, int) = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (h) sbsOpen = (void (*)(CFURLRef, int))dlsym(h, "SBSOpenSensitiveURL");
    });
    if (sbsOpen) {
        sbsOpen((__bridge CFURLRef)url, 0);
        MGLog(@"打开链接成功 (%@)", url);
        return;
    }
    MGLog(@"打开链接失败: SBSOpenSensitiveURL 不可用");
}

#pragma mark - 应用抽屉 (0.5.0): 左滑弹出应用面板, 点图标直接打开

static void MGHaptic(void);       // 前置声明(实现在媒体区)
static void MGDrawerDismiss(void); // 前置声明(定义在抽屉区末尾)
static BOOL MGLaunchApp(NSString *bid); // 前置声明

// tweak 侧应用枚举 (与面板同一过滤规则: 预装+沙盒, 排除无图标系统级程序)
static NSArray *MGTweakAppRows(void)
{
    static NSArray *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *rows = [NSMutableArray array];
        @try {
            Class wsClass = objc_getClass("LSApplicationWorkspace");
            id ws = wsClass ? ((id (*)(id, SEL))objc_msgSend)(wsClass, sel_registerName("defaultWorkspace")) : nil;
            NSArray *apps = nil;
            if (ws) {
                SEL s = sel_registerName("allInstalledApplications"); // 16.6 真名
                if ([ws respondsToSelector:s]) apps = ((NSArray *(*)(id, SEL))objc_msgSend)(ws, s);
            }
            for (id app in apps ?: @[]) {
                @try {
                    NSString *bid = [app respondsToSelector:@selector(bundleIdentifier)] ? [app bundleIdentifier] : nil;
                    if (!bid.length) continue;
                    NSString *name = nil;
                    for (NSString *selName in @[@"localizedDisplayName", @"localizedName"]) {
                        SEL s = NSSelectorFromString(selName);
                        if ([app respondsToSelector:s]) {
                            NSString *n = ((NSString *(*)(id, SEL))objc_msgSend)(app, s);
                            if (n.length) { name = n; break; }
                        }
                    }
                    if (!name.length) name = bid;
                    NSString *appType = nil;
                    if ([app respondsToSelector:@selector(applicationType)]) {
                        id t = ((id (*)(id, SEL))objc_msgSend)(app, @selector(applicationType));
                        if ([t isKindOfClass:[NSString class]]) appType = t;
                    }
                    NSString *bundlePath = nil;
                    if ([app respondsToSelector:@selector(bundleURL)]) {
                        NSURL *u = [app bundleURL];
                        bundlePath = u ? u.path : nil;
                    }
                    BOOL isUser = [appType isEqualToString:@"User"];
                    BOOL hasIconFile = NO;
                    if (bundlePath.length) {
                        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
                            [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
                        NSDictionary *icons = info[@"CFBundleIcons"];
                        hasIconFile = [icons isKindOfClass:[NSDictionary class]] &&
                            [icons[@"CFBundlePrimaryIcon"] isKindOfClass:[NSDictionary class]];
                    }
                    if (!isUser && !(hasIconFile && [appType isEqualToString:@"System"])) continue;
                    [rows addObject:@[name, bid, bundlePath ?: @""]];
                } @catch (NSException *e) {}
            }
            [rows sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
                return [a[0] compare:b[0] options:NSNumericSearch | NSCaseInsensitiveSearch];
            }];
        } @catch (NSException *e) { MGLog(@"抽屉枚举失败: %@", e); }
        cached = [rows copy];
    });
    return cached;
}

// 图标缓存: %ctor 后台预热全部图标, 抽屉打开零等待
static NSMutableDictionary *mgTweakIconCache = nil;

static UIImage *MGTweakIcon(NSString *bid, NSString *bundlePath)
{
    if (!mgTweakIconCache) mgTweakIconCache = [NSMutableDictionary new];
    UIImage *cached = mgTweakIconCache[bid];
    if (cached) return cached;
    UIImage *img = nil;
    if (bundlePath.length) {
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:
            [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
        if ([info isKindOfClass:[NSDictionary class]]) {
            NSString *name = nil;
            NSDictionary *icons = info[@"CFBundleIcons"];
            if ([icons isKindOfClass:[NSDictionary class]]) {
                NSDictionary *primary = icons[@"CFBundlePrimaryIcon"];
                if ([primary isKindOfClass:[NSDictionary class]]) {
                    NSArray *files = primary[@"CFBundleIconFiles"];
                    if ([files isKindOfClass:[NSArray class]] && files.count > 0) name = files.lastObject;
                }
            }
            if (!name.length) name = info[@"CFBundleIconFile"];
            if (name.length) {
                for (NSString *cand in @[[NSString stringWithFormat:@"%@@2x.png", name],
                                         [NSString stringWithFormat:@"%@@3x.png", name],
                                         [name stringByAppendingPathExtension:@"png"], name]) {
                    UIImage *raw = [UIImage imageWithContentsOfFile:[bundlePath stringByAppendingPathComponent:cand]];
                    if (raw) {
                        UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40, 40)];
                        img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                            [raw drawInRect:CGRectMake(0, 0, 40, 40)];
                        }];
                        break;
                    }
                }
            }
        }
    }
    if (!img) img = [UIImage new]; // 占位避免重复读盘
    mgTweakIconCache[bid] = img;
    return img;
}

@interface MGDrawerCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *label;
@end
@implementation MGDrawerCell
- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _iconView = [[UIImageView alloc] initWithFrame:CGRectMake(15, 8, 40, 40)];
        _iconView.layer.cornerRadius = 9.0;
        _iconView.clipsToBounds = YES;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:_iconView];
        _label = [[UILabel alloc] initWithFrame:CGRectMake(2, 50, 66, 14)];
        _label.font = [UIFont systemFontOfSize:10];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = UIColor.whiteColor;
        _label.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_label];
    }
    return self;
}
@end

@interface MGDrawerController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, assign) CGRect panelFrame;
@end
@implementation MGDrawerController

- (void)viewDidLoad
{
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
    CGFloat w = self.view.bounds.size.width;
    CGFloat panelW = w - 40, panelH = 470;
    UIView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    panel.frame = CGRectMake(20, (self.view.bounds.size.height - panelH) / 2.0, panelW, panelH);
    panel.layer.cornerRadius = 20.0;
    panel.clipsToBounds = YES;
    _panelFrame = panel.frame;
    [self.view addSubview:panel];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, panelW, 18)];
    title.text = @"应用抽屉 · 点图标打开 · 点外面关闭";
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont systemFontOfSize:12];
    title.textColor = [UIColor colorWithWhite:1 alpha:0.8];
    [panel addSubview:title];

    UICollectionViewFlowLayout *fl = [[UICollectionViewFlowLayout alloc] init];
    fl.itemSize = CGSizeMake(70, 74);
    fl.minimumInteritemSpacing = 6;
    fl.minimumLineSpacing = 6;
    fl.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8);
    UICollectionView *grid = [[UICollectionView alloc] initWithFrame:
        CGRectMake(0, 34, panelW, panelH - 34) collectionViewLayout:fl];
    grid.dataSource = self;
    grid.delegate = self;
    grid.backgroundColor = UIColor.clearColor;
    [grid registerClass:[MGDrawerCell class] forCellWithReuseIdentifier:@"mgcell"];
    [panel addSubview:grid];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(bgTap:)];
    [self.view addGestureRecognizer:tap];
}

- (void)bgTap:(UITapGestureRecognizer *)t
{
    CGPoint p = [t locationInView:self.view];
    if (!CGRectContainsPoint(_panelFrame, p)) MGDrawerDismiss();
}

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section
{
    return MGTweakAppRows().count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    MGDrawerCell *cell = [cv dequeueReusableCellWithReuseIdentifier:@"mgcell" forIndexPath:indexPath];
    NSArray *row = MGTweakAppRows()[indexPath.item];
    cell.label.text = row[0];
    cell.iconView.image = MGTweakIcon(row[1], row[2]);
    return cell;
}

- (void)collectionView:(UICollectionView *)cv didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *row = MGTweakAppRows()[indexPath.item];
    MGHaptic();
    MGLaunchApp(row[1]);
    MGLog(@"抽屉打开应用: %@", row[1]);
    MGDrawerDismiss();
}

@end

static UIWindow *mgDrawerWindow = nil;

static void MGDrawerDismiss(void)
{
    if (mgDrawerWindow) {
        UIWindow *w = mgDrawerWindow;
        mgDrawerWindow = nil;
        w.hidden = YES;
    }
}

static void MGShowDrawer(void)
{
    if (mgDrawerWindow) { MGDrawerDismiss(); return; } // 再触发一次 = 关闭
    id scene = [[UIApplication sharedApplication].connectedScenes anyObject];
    if (!scene) { MGLog(@"抽屉失败: 无 windowScene"); return; }
    mgDrawerWindow = [[UIWindow alloc] initWithWindowScene:scene];
    mgDrawerWindow.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
    mgDrawerWindow.windowLevel = UIWindowLevelAlert + 100;
    mgDrawerWindow.rootViewController = [MGDrawerController new];
    [mgDrawerWindow makeKeyAndVisible];
    MGLog(@"应用抽屉已显示 (%u 个应用)", (unsigned)MGTweakAppRows().count);
}

// 执行预设链接: 按名称查 links 预设表 (数组, 每项 {n:名称, u:网址})
static void MGRunLink(NSString *name)
{
    NSArray *links = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)@"links", (__bridge CFStringRef)kSuite));
    if ([links isKindOfClass:[NSArray class]]) {
        for (NSDictionary *d in links) {
            if ([d isKindOfClass:[NSDictionary class]] && [name isEqualToString:d[@"n"]]) {
                NSString *u = d[@"u"];
                if ([u isKindOfClass:[NSString class]] && u.length > 0) { MGOpenURLString(u); return; }
            }
        }
    }
    MGLog(@"打开链接失败: 找不到预设「%@」(可在 我的链接 里检查)", name);
}

// 震动: CoreHaptics 引擎 (连点器项目真机验证过的方案) + AudioServices 兜底
static CHHapticEngine *mgHapticEngine = nil;

static void MGInitHapticEngine(void)
{
    if (mgHapticEngine) return;
    if (![CHHapticEngine capabilitiesForHardware].supportsHaptics) return;
    NSError *err = nil;
    mgHapticEngine = [[CHHapticEngine alloc] initAndReturnError:&err];
    if (err) { mgHapticEngine = nil; return; }
    [mgHapticEngine startWithCompletionHandler:nil];
}

static void MGHaptic(void)
{
    if (!MGPrefBool(@"hapticsEnabled", YES)) return;
    MGInitHapticEngine();
    if (mgHapticEngine) {
        @try {
            CHHapticEventParameter *intensity = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0];
            CHHapticEventParameter *sharpness = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.6];
            CHHapticEvent *event = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticTransient parameters:@[intensity, sharpness] relativeTime:0];
            NSError *perr = nil;
            CHHapticPattern *pattern = [[CHHapticPattern alloc] initWithEvents:@[event] parameters:@[] error:&perr];
            if (!perr) {
                id<CHHapticPatternPlayer> player = [mgHapticEngine createPlayerWithPattern:pattern error:&perr];
                if (!perr) [player startAtTime:0 error:nil];
            }
        } @catch (NSException *e) { MGLog(@"CoreHaptics 异常: %@", e); }
    }
    AudioServicesPlaySystemSound(4095); // 双保险
}

static void MGPerformInSpringBoard(NSString *action)
{
    if ([action isEqualToString:@"lock"])              MGLockScreen();
    else if ([action isEqualToString:@"screenshot"])  MGScreenshot();
    else if ([action isEqualToString:@"flashlight"])  MGToggleFlashlight();
    else if ([action isEqualToString:@"respring"])    MGRespring();
    else if ([action isEqualToString:@"home"])        MGGoHome();
    else if ([action isEqualToString:@"settingspanel"]) MGOpenPrefsPanel();
    else if ([action isEqualToString:@"ctrlcenter"])  MGOpenControlCenter();
    else if ([action isEqualToString:@"bluetooth"])   MGToggleBluetooth();
    else if ([action isEqualToString:@"appswitcher"]) MGAppSwitcher();
    else if ([action isEqualToString:@"camera"])       MGCameraOpen();
    else if ([action isEqualToString:@"sn3"])         MGTriggerSN3();
}

/* ============ darwin 通知: 把 App 内的手势转发给 SpringBoard ============ */

static void MGDarwinCallback(CFNotificationCenterRef center, void *observer,
                             CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSString *n = (__bridge NSString *)name;
    if (![n hasPrefix:kNotifyPrefix]) return;
    NSString *action = [n substringFromIndex:kNotifyPrefix.length];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([action isEqualToString:@"link"]) { // 取出转发来的链接名称
            NSString *name = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)@"pendingLink", (__bridge CFStringRef)kSuite));
            if ([name isKindOfClass:[NSString class]] && name.length > 0) MGRunLink(name);
            return;
        }
        if ([action isEqualToString:@"run"]) { // 取出转发来的带参数动作 (app:/link:)
            NSString *a = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)@"pendingAction", (__bridge CFStringRef)kSuite));
            if ([a isKindOfClass:[NSString class]] && a.length > 0) MGDispatchAction(a);
            return;
        }
        MGPerformInSpringBoard(action);
    });
}

static void MGDispatchAction(NSString *action)
{
    if (!MGActionEnabled(action)) return;
    if (MGIsSpringBoard()) {
        // 全局开关: 锁屏界面手势 (App 内不受影响, App 前台时必非锁屏)
        if (MGPrefBool(@"lockScreenEnabled", YES) == NO && MGUILocked()) {
            MGLog(@"锁屏界面手势已全局关闭, 忽略动作: %@", action);
            return;
        }
        MGHaptic(); // 即时震动反馈 (识别到手势立刻响应, 不等动作执行)
        if ([action hasPrefix:@"link:"]) { // 预设链接: 按名称执行
            MGRunLink([action substringFromIndex:5]);
            return;
        }
        if ([action hasPrefix:@"app:"]) { // 打开应用: 按 bundle id 走 SBS 启动
            MGOpenAppByID([action substringFromIndex:4]);
            return;
        }
        MGLog(@"触发动作: %@", action);
        MGPerformInSpringBoard(action);
    } else {
        if ([action hasPrefix:@"app:"] || [action hasPrefix:@"link:"]) { // 带参数动作: 载荷写偏好, 发通用通知
            CFPreferencesSetAppValue((__bridge CFStringRef)@"pendingAction",
                (__bridge CFTypeRef)action, (__bridge CFStringRef)kSuite);
            CFPreferencesAppSynchronize((__bridge CFStringRef)kSuite);
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:@"run"],
                NULL, NULL, TRUE);
            return;
        }
        MGLog(@"转发动作给 SpringBoard: %@", action);
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:action],
            NULL, NULL, TRUE);
    }
}

/* ========================= 手势识别 ========================= */

// App 黑名单: 命中则该 App 内全部状态栏手势失效 (SpringBoard 不受黑名单影响)
static BOOL MGAppBlacklisted(void)
{
    if (MGIsSpringBoard()) return NO;
    NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
    if (!bid.length) return NO;
    return MGPrefBool([@"bl_" stringByAppendingString:bid], NO);
}

@interface MGTracker : NSObject
@property (nonatomic, assign) BOOL tracking;
@property (nonatomic, weak)   UIWindow *window;
@property (nonatomic, assign) CGPoint beginPoint;
@property (nonatomic, assign) CFTimeInterval beginTime;
@property (nonatomic, assign) MGEar beginEar;      // 本次触摸开始的耳朵
@property (nonatomic, assign) NSUInteger tapCount; // 已累计的点击数
@property (nonatomic, assign) MGEar tapEar;        // 已累计点击所属的耳朵 (双击必须同耳)
@property (nonatomic, strong) NSTimer *mergeTimer;
+ (instancetype)sharedTracker;
- (void)touchBegan:(UITouch *)t inWindow:(UIWindow *)w;
- (void)touchEnded:(UITouch *)t inWindow:(UIWindow *)w;
- (void)reset;
@end

@implementation MGTracker

+ (instancetype)sharedTracker
{
    static MGTracker *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [MGTracker new]; });
    return s;
}

- (void)reset
{
    _tracking = NO;
    _tapCount = 0;
    [_mergeTimer invalidate];
    _mergeTimer = nil;
}

- (void)clearTapChain
{
    _tapCount = 0;
    _tapEar = MGEarNone;
    [_mergeTimer invalidate];
    _mergeTimer = nil;
}

// 间隔计时器到点: 仍只有一次点击 → 触发单击
- (void)mergeTimerFired:(NSTimer *)tm
{
    _mergeTimer = nil;
    if (_tapCount == 1) {
        MGEar ear = _tapEar;
        _tapCount = 0;
        _tapEar = MGEarNone;
        MGDispatchAction(MGActionForGesture(ear, @"singleTap"));
    } else {
        _tapCount = 0;
        _tapEar = MGEarNone;
    }
}

- (void)touchBegan:(UITouch *)t inWindow:(UIWindow *)w
{
    if (MGAppBlacklisted()) { [self reset]; return; }

    CGPoint p = [t locationInView:w];
    MGEar ear = MGEarForPoint(w, p);
    if (ear == MGEarNone) {
        // 状态栏区域外 / 刘海·灵动岛本体 / 黑名单App → 不记录, 触摸原样透传系统
        [self reset];
        return;
    }
    _tracking   = YES;
    _window     = w;
    _beginPoint = p;
    _beginTime  = CACurrentMediaTime();
    _beginEar   = ear;
}

- (void)touchEnded:(UITouch *)t inWindow:(UIWindow *)w
{
    if (!_tracking) return;
    _tracking = NO;

    CGPoint p = [t locationInView:w];
    CGFloat dx = p.x - _beginPoint.x;
    CGFloat dy = p.y - _beginPoint.y;
    CFTimeInterval dt = CACurrentMediaTime() - _beginTime;

    // 长按 / 大幅下拉(通知中心·控制中心手势) → 全部交给系统, 不做任何手势
    if (dt > 0.45 || fabs(dy) > 140.0) { [self reset]; return; }

    // 左滑: 优先判定水平滑动, Y 轴偏移过大直接过滤 (右滑不做手势)
    if (fabs(dx) >= 45.0) {
        if (fabs(dy) <= 70.0 && fabs(dx) > fabs(dy) * 1.5 && dx < 0.0) {
            MGEar ear = _beginEar;
            [self reset];
            MGDispatchAction(MGActionForGesture(ear, @"swipeLeft"));
        } else {
            [self reset];
        }
        return;
    }

    // 点按 (位移很小才算一次 tap)
    if (hypot(dx, dy) <= 30.0) {
        MGEar ear = _beginEar;

        // 双击必须落在同一个耳朵区域, 跨耳朵点击重新计一次
        if (_tapEar != ear || _tapCount == 0) {
            _tapEar = ear;
            _tapCount = 1;
        } else {
            _tapCount++;
        }

        // 同耳双击 → 直接触发
        if (_tapCount >= 2) {
            [self clearTapChain];
            MGDispatchAction(MGActionForGesture(ear, @"doubleTap"));
            return;
        }

        // 单击与双击都没绑定动作 → 不必计时, 直接结束
        BOOL sEn = MGActionEnabled(MGActionForGesture(ear, @"singleTap"));
        BOOL dEn = MGActionEnabled(MGActionForGesture(ear, @"doubleTap"));
        if (!sEn && !dEn) { [self clearTapChain]; return; }

        // 等用户设定的间隔, 看第二次点击是否落进来 (落不进来 = 单击)
        [_mergeTimer invalidate];
        NSTimeInterval interval = MGPrefFloat(@"tapInterval", 0.32);
        if (interval < 0.20) interval = 0.20;
        if (interval > 0.50) interval = 0.50;
        __weak MGTracker *ws = self;
        _mergeTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:NO block:^(NSTimer *tm) {
            [ws mergeTimerFired:tm];
        }];
    } else {
        [self reset];
    }
}

@end

/* ========================= Hook ========================= */

%hook SBCameraHardwareButton

- (id)init {
    %orig;
    gCameraButtonInstance = self;
    MGLog(@"SBCameraHardwareButton 实例已捕获");
    return self;
}

%end

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    %orig; // 只观察, 不拦截: 下滑/长按/三击/上滑等事件完整透传给系统

    @try {
        if (event.type != UIEventTypeTouches) return;
        NSSet *all = [event allTouches];
        if (all.count != 1) { [[MGTracker sharedTracker] reset]; return; }
        UITouch *t = all.anyObject;
        if (!t) return;

        switch (t.phase) {
            case UITouchPhaseBegan:
                [[MGTracker sharedTracker] touchBegan:t inWindow:self];
                break;
            case UITouchPhaseEnded:
                [[MGTracker sharedTracker] touchEnded:t inWindow:self];
                break;
            case UITouchPhaseCancelled:
                [[MGTracker sharedTracker] reset];
                break;
            default:
                break;
        }
    } @catch (NSException *e) {
        MGLog(@"sendEvent 异常: %@", e);
    }
}

%end

%ctor
{
    @autoreleasepool {
        if (MGIsSpringBoard()) {
            CFNotificationCenterRef nc = CFNotificationCenterGetDarwinNotifyCenter();
            for (NSString *a in @[@"lock", @"screenshot", @"respring", @"flashlight", @"home", @"settingspanel", @"ctrlcenter", @"bluetooth", @"appswitcher", @"sn3", @"link", @"run"]) {
                CFNotificationCenterAddObserver(nc, NULL, MGDarwinCallback,
                    (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:a],
                    NULL, CFNotificationSuspensionBehaviorCoalesce);
            }
            MGLog(@"已加载到 SpringBoard v0.5.1 (耳朵分区/刘海灵动岛丢弃/下滑透传)");
            // 后台预热: 应用列表 + 全部图标 (应用抽屉秒开)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool {
                    NSArray *rows = MGTweakAppRows();
                    for (NSArray *r in rows) MGTweakIcon(r[1], r[2]);
                    MGLog(@"抽屉预热完成 (%u 应用)", (unsigned)rows.count);
                }
            });
        }
    }
}
