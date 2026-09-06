/**
 * MyGestures —— 状态栏手势插件 (rootless)
 *
 * 适用环境: iPhone 12 Pro / iOS 16.6.1 / Relaxin (基于 Dopamine 的 rootless 越狱)
 * 构建方式: Theos, 需设置 THEOS_PACKAGE_SCHEME=rootless
 *
 * 手势 (作用于屏幕最顶部"状态栏"区域, 任何界面都有效, 包括锁屏):
 *   - 单击 / 双击 / 三击状态栏
 *   - 状态栏左滑 / 右滑
 *
 * 可绑定动作:
 *   无 / 锁屏 / 截屏 / 注销(respring) / 手电筒开关
 *
 * 工作原理:
 *   注入所有 UIKit 进程 (filter = com.apple.UIKit), hook UIWindow 的 sendEvent:
 *   - 在 SpringBoard 进程内识别到手势 -> 直接执行动作
 *   - 在其它 App 内识别到手势       -> 通过 darwin 通知转发给 SpringBoard 执行
 */

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <dispatch/dispatch.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <math.h>

#define MGLog(fmt, ...) NSLog(@"[MyGestures] " fmt, ##__VA_ARGS__)

/* ========================= 偏好设置 ========================= */

// rootless 越狱的偏好路径是 /var/jb 前缀, 但有的工具仍写旧路径, 两个都尝试
static NSString *const kPrefPathRootless = @"/var/jb/var/mobile/Library/Preferences/com.local.mygestures.plist";
static NSString *const kPrefPathLegacy   = @"/var/mobile/Library/Preferences/com.local.mygestures.plist";
static NSString *const kNotifyPrefix     = @"com.local.mygestures.";

static NSDictionary *MGReadPrefs(void)
{
    NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:kPrefPathRootless];
    if (!d) d = [NSDictionary dictionaryWithContentsOfFile:kPrefPathLegacy];
    return d ?: @{};
}

// 出厂默认动作 (设置面板没保存过时使用)
static NSString *MGDefaultActionForKey(NSString *key)
{
    if ([key isEqualToString:@"doubleTap"]) return @"lock";        // 双击状态栏 = 锁屏
    if ([key isEqualToString:@"tripleTap"]) return @"screenshot";  // 三击状态栏 = 截屏
    if ([key isEqualToString:@"swipeLeft"]) return @"flashlight";  // 状态栏左滑 = 手电筒
    return @"none";                                                // 单击 / 右滑默认关闭, 避免误触
}

static NSString *MGActionForGesture(NSString *key)
{
    NSString *v = MGReadPrefs()[key];
    return ([v isKindOfClass:[NSString class]] && v.length > 0) ? v : MGDefaultActionForKey(key);
}

static BOOL MGActionEnabled(NSString *action)
{
    return action.length > 0 && ![action isEqualToString:@"none"];
}

/* ================== 动作执行 (只能在 SpringBoard 进程内做) ================== */

static BOOL MGIsSpringBoard(void)
{
    static BOOL isSB = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        isSB = [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
    });
    return isSB;
}

static void MGLockScreen(void)
{
    // 主路径: SpringBoard 内部类 SBUIController 的 -lock
    Class c = objc_getClass("SBUIController");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)((id)c, sel_registerName("sharedInstance"));
        SEL lockSel = sel_registerName("lock");
        if (inst && [inst respondsToSelector:lockSel]) {
            ((void (*)(id, SEL))objc_msgSend)(inst, lockSel);
            MGLog(@"锁屏成功 (SBUIController lock)");
            return;
        }
    }
    // 备用路径: SpringBoardServices 的 SBSLockDevice(), 用 dlsym 动态探测, 不存在则跳过
    void *h = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    if (h) {
        void (*lockDev)(void) = (void (*)(void))dlsym(h, "SBSLockDevice");
        if (lockDev) {
            lockDev();
            MGLog(@"锁屏成功 (SBSLockDevice)");
            return;
        }
    }
    MGLog(@"锁屏失败: 未找到可用方法 (SBUIController / SBSLockDevice)");
}

static void MGScreenshot(void)
{
    // SpringBoard 内部类 SBScreenShotter, 不同系统版本方法名不同, 逐个尝试
    Class c = objc_getClass("SBScreenShotter");
    if (c) {
        id inst = ((id (*)(id, SEL))objc_msgSend)((id)c, sel_registerName("sharedInstance"));
        if (inst) {
            NSArray *names = @[@"saveScreenshot", @"saveScreenshot:", @"takeScreenshot"];
            for (NSString *n in names) {
                SEL s = NSSelectorFromString(n);
                if ([inst respondsToSelector:s]) {
                    if ([n hasSuffix:@":"])
                        ((void (*)(id, SEL, id))objc_msgSend)(inst, s, nil);
                    else
                        ((void (*)(id, SEL))objc_msgSend)(inst, s);
                    MGLog(@"截屏成功 (SBScreenShotter %@)", n);
                    return;
                }
            }
        }
    }
    MGLog(@"截屏失败: SBScreenShotter 不可用");
}

static void MGToggleFlashlight(void)
{
    AVCaptureDevice *dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!dev || !dev.hasTorch) {
        MGLog(@"手电筒失败: 无闪光灯设备");
        return;
    }
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
    exit(0); // launchd 会自动重新拉起 SpringBoard
}

static void MGPerformInSpringBoard(NSString *action)
{
    if ([action isEqualToString:@"lock"])             MGLockScreen();
    else if ([action isEqualToString:@"screenshot"]) MGScreenshot();
    else if ([action isEqualToString:@"flashlight"]) MGToggleFlashlight();
    else if ([action isEqualToString:@"respring"])   MGRespring();
}

/* ============ darwin 通知: 把 App 内的手势转发给 SpringBoard ============ */

static void MGDarwinCallback(CFNotificationCenterRef center, void *observer,
                             CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSString *n = (__bridge NSString *)name;
    if (![n hasPrefix:kNotifyPrefix]) return;
    NSString *action = [n substringFromIndex:kNotifyPrefix.length];
    MGLog(@"收到转发动作: %@", action);
    dispatch_async(dispatch_get_main_queue(), ^{
        MGPerformInSpringBoard(action);
    });
}

static void MGDispatchAction(NSString *action)
{
    if (!MGActionEnabled(action)) return;
    MGLog(@"触发动作: %@ (%@)", action, MGIsSpringBoard() ? @"SpringBoard 内" : @"转发给 SpringBoard");
    if (MGIsSpringBoard()) {
        MGPerformInSpringBoard(action);
    } else {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:action],
            NULL, NULL, TRUE);
    }
}

/* ========================= 手势识别 ========================= */

// 手势判定区域: 状态栏高度 + 12pt 容差
static CGFloat MGStatusZoneHeight(UIWindow *w)
{
    CGFloat top = w.safeAreaInsets.top; // 12 Pro 竖屏为 47pt
    if (top < 20) top = 20;             // 无刘海 / 横屏时的兜底
    if (top > 90) top = 59;
    return top + 12.0;
}

@interface MGTracker : NSObject
@property (nonatomic, assign) BOOL tracking;
@property (nonatomic, weak)   UIWindow *window;
@property (nonatomic, assign) CGPoint beginPoint;
@property (nonatomic, assign) CFTimeInterval beginTime;
@property (nonatomic, assign) NSUInteger tapCount;
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

- (void)fireTapCount:(NSUInteger)n
{
    [self reset];
    NSString *key = (n >= 3) ? @"tripleTap" : (n == 2 ? @"doubleTap" : @"singleTap");
    MGDispatchAction(MGActionForGesture(key));
}

- (void)touchBegan:(UITouch *)t inWindow:(UIWindow *)w
{
    CGPoint p = [t locationInView:w];
    if (p.y < 0.0 || p.y > MGStatusZoneHeight(w)) {
        [self reset]; // 状态栏区域外的触摸会打断点按计数
        return;
    }
    _tracking = YES;
    _window = w;
    _beginPoint = p;
    _beginTime = CACurrentMediaTime();
}

- (void)touchEnded:(UITouch *)t inWindow:(UIWindow *)w
{
    if (!_tracking) return;
    _tracking = NO;

    CGPoint p = [t locationInView:w];
    CGFloat dx = p.x - _beginPoint.x;
    CGFloat dy = p.y - _beginPoint.y;
    CFTimeInterval dt = CACurrentMediaTime() - _beginTime;

    // 按住太久 / 大幅垂直移动(如下拉通知中心) —— 一律忽略, 避免误触
    if (dt > 0.45 || fabs(dy) > 140.0) {
        [self reset];
        return;
    }

    // 水平滑动手势
    if (fabs(dx) >= 45.0 && fabs(dy) <= 70.0 && fabs(dx) > fabs(dy) * 1.5) {
        [self reset];
        NSString *key = (dx > 0.0) ? @"swipeRight" : @"swipeLeft";
        MGDispatchAction(MGActionForGesture(key));
        return;
    }

    // 点按手势 (位移很小才算一次 tap)
    if (hypot(dx, dy) <= 30.0) {
        _tapCount++;
        [_mergeTimer invalidate];
        _mergeTimer = nil;

        if (_tapCount >= 3) { // 三击封顶, 直接触发
            [self fireTapCount:_tapCount];
            return;
        }
        // 双击/三击都没绑定动作时, 单击零延迟触发;
        // 否则等 0.32 秒把连续点击合并成双击/三击
        BOOL hasDouble = MGActionEnabled(MGActionForGesture(@"doubleTap"));
        BOOL hasTriple = MGActionEnabled(MGActionForGesture(@"tripleTap"));
        if (_tapCount == 1 && !hasDouble && !hasTriple) {
            [self fireTapCount:1];
            return;
        }
        __weak MGTracker *ws = self;
        _mergeTimer = [NSTimer scheduledTimerWithTimeInterval:0.32 repeats:NO block:^(NSTimer *tm) {
            [ws mergeTimerFired:tm];
        }];
    } else {
        [self reset];
    }
}

- (void)mergeTimerFired:(NSTimer *)tm
{
    _mergeTimer = nil;
    NSUInteger n = _tapCount;
    _tapCount = 0;
    if (n > 0) {
        NSString *key = (n >= 3) ? @"tripleTap" : (n == 2 ? @"doubleTap" : @"singleTap");
        MGDispatchAction(MGActionForGesture(key));
    }
}

@end

/* ========================= Hook ========================= */

%hook UIWindow

- (void)sendEvent:(UIEvent *)event
{
    %orig; // 只观察, 不拦截, 不影响系统任何原有行为

    @try {
        if (event.type != UIEventTypeTouches) return;
        NSSet *all = [event allTouches];
        if (all.count != 1) { // 多指触摸一律忽略
            [[MGTracker sharedTracker] reset];
            return;
        }
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
            for (NSString *a in @[@"lock", @"screenshot", @"respring", @"flashlight"]) {
                CFNotificationCenterAddObserver(nc, NULL, MGDarwinCallback,
                    (__bridge CFStringRef)[kNotifyPrefix stringByAppendingString:a],
                    NULL, CFNotificationSuspensionBehaviorCoalesce);
            }
            MGLog(@"已加载到 SpringBoard, 动作接收端就绪");
        }
    }
}
