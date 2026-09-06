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
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <math.h>

#define MGLog(fmt, ...) NSLog(@"[MyGestures] " fmt, ##__VA_ARGS__)

/* ========================= 偏好设置 ========================= */

static NSString *const kSuite        = @"com.local.mygestures";
static NSString *const kNotifyPrefix = @"com.local.mygestures.";

static id MGPrefValue(NSString *key)
{
    CFPreferencesAppSynchronize((__bridge CFStringRef)kSuite);
    CFTypeRef raw = CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)kSuite);
    return raw ? CFBridgingRelease(raw) : nil;
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

static void MGToggleWiFi(void)
{
    MGToggleSetting(@[@"SBWiFiManager"],
                    @[@"wifiEnabled", @"isWiFiEnabled"],
                    @[@"setWiFiEnabled:", @"setWiFiPowered:"],
                    @"WiFi开关");
}

static void MGToggleBluetooth(void)
{
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

// 从 SpringBoard 打开 URL (16.6 实测安全不崩的通路)
static void MGOpenURLString(NSString *urlString)
{
    if (urlString.length == 0) { MGLog(@"打开链接失败: 空地址"); return; }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url || !url.scheme)
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:urlString]]; // 裸域名兜底
    if (!url) { MGLog(@"打开链接失败: 无效地址 %@", urlString); return; }
    Class c = objc_getClass("FBSSystemService");
    if (c) {
        id svc = ((id (*)(id, SEL))objc_msgSend)(c, sel_registerName("sharedService"));
        SEL o = sel_registerName("openURL:application:options:clientPort:withResult:");
        if (svc && [svc respondsToSelector:o]) {
            ((void (*)(id, SEL, id, id, id, unsigned int, id))objc_msgSend)(svc, o, url, nil, nil, 0, nil);
            MGLog(@"打开链接成功 (%@)", url);
            return;
        }
    }
    MGLog(@"打开链接失败: FBSSystemService 不可用");
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

static void MGHaptic(void)
{
    if (!MGPrefBool(@"hapticsEnabled", YES)) return;
    // 主: 系统震动 4095 (AudioServices, SpringBoard 内最稳); 备: 触觉引擎 (SB 内可能无声反馈)
    AudioServicesPlaySystemSound(4095);
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [g impactOccurred];
            } @catch (NSException *e) {}
        });
        return;
    }
    @try {
        UIImpactFeedbackGenerator *g = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [g impactOccurred];
    } @catch (NSException *e) {}
}

static void MGPerformInSpringBoard(NSString *action)
{
    if ([action isEqualToString:@"lock"])              MGLockScreen();
    else if ([action isEqualToString:@"screenshot"])  MGScreenshot();
    else if ([action isEqualToString:@"flashlight"])  MGToggleFlashlight();
    else if ([action isEqualToString:@"respring"])    { MGHaptic(); MGRespring(); return; }
    else if ([action isEqualToString:@"home"])        MGGoHome();
    else if ([action isEqualToString:@"settingspanel"]) MGOpenPrefsPanel();
    else if ([action isEqualToString:@"wifi"])        MGToggleWiFi();
    else if ([action isEqualToString:@"bluetooth"])   MGToggleBluetooth();
    else if ([action isEqualToString:@"airplane"])    MGToggleAirplane();
    else if ([action isEqualToString:@"lowpower"])    MGToggleLowPower();
    else if ([action isEqualToString:@"playpause"])   MGTogglePlayPause();
    else if ([action isEqualToString:@"nexttrack"])   MGNextTrack();
    else if ([action isEqualToString:@"prevtrack"])   MGPrevTrack();
    else if ([action isEqualToString:@"volup"])       MGVolUp();
    else if ([action isEqualToString:@"voldown"])     MGVolDown();
    else if ([action isEqualToString:@"mute"])        MGMute();
    else if ([action isEqualToString:@"appswitcher"]) MGAppSwitcher();
    MGHaptic(); // 手势执行成功震动
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
        if ([action hasPrefix:@"link:"]) { // 预设链接: 按名称执行
            MGRunLink([action substringFromIndex:5]);
            MGHaptic();
            return;
        }
        MGLog(@"触发动作: %@", action);
        MGPerformInSpringBoard(action);
    } else {
        if ([action hasPrefix:@"link:"]) { // 先把链接名称写进偏好, 再发通用通知 (通知名有长度限制)
            CFPreferencesSetAppValue((__bridge CFStringRef)@"pendingLink",
                (__bridge CFTypeRef)[action substringFromIndex:5], (__bridge CFStringRef)kSuite);
            CFPreferencesAppSynchronize((__bridge CFStringRef)kSuite);
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:@"link"],
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

%hook UIWindow

- (void)sendEvent:(UIEvent *)event
{
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
            for (NSString *a in @[@"lock", @"screenshot", @"respring", @"flashlight", @"home", @"settingspanel",
                                  @"wifi", @"bluetooth", @"airplane", @"lowpower", @"playpause", @"nexttrack", @"prevtrack",
                                  @"volup", @"voldown", @"mute", @"appswitcher", @"link"]) {
                CFNotificationCenterAddObserver(nc, NULL, MGDarwinCallback,
                    (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:a],
                    NULL, CFNotificationSuspensionBehaviorCoalesce);
            }
            MGLog(@"已加载到 SpringBoard v0.1.0 (耳朵分区/刘海灵动岛丢弃/下滑透传)");
        }
    }
}
