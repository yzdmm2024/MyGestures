// MyGestures 动作选择子页面 v0.1.5
// 主页面每个手势行 (PSLinkCell) 推入对应子类; 子页面每行一个 PSSwitchCell (真机验证可交互),
// 单选逻辑由本控制器实现: 打开一项 → 写入手势键并刷新 (其他项自动变关); 关掉当前项 → 变「无」
// 注: PSButtonCell 在真机上点按不触发, PSListItemCell 点按无响应, 均已弃用
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define MG_SUITE @"com.local.mygestures"

NSArray *MGLinksRead(void); // 在 MGLinksController.m 中实现
NSString *MGAppTitleForBid(NSString *bid); // 在 MGAppPickerController.m 中实现

static id MGNewSpec(id ctrl, NSString *name, id target, SEL set, SEL get, id detail, NSInteger cell)
{
    SEL sel = NSSelectorFromString(@"preferenceSpecifierNamed:target:set:get:detail:cell:edit:");
    id (*msg)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger) =
        (id (*)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger))objc_msgSend;
    Class ps = objc_getClass("PSSpecifier");
    return msg(ps, sel, name, target, set, get, detail, cell, 0);
}

#pragma mark - 动作标题表

NSString *MGActionTitle(NSString *act)
{
    NSDictionary *map = @{
        @"none":          @"无",
        @"lock":          @"锁屏",
        @"screenshot":    @"截屏",
        @"flashlight":    @"手电筒开关",
        @"respring":      @"Respring注销",
        @"home":          @"返回主屏幕",
        @"settingspanel": @"打开本工具设置面板",
        @"wifi":          @"WiFi开关",
        @"bluetooth":     @"蓝牙开关",
        @"airplane":      @"飞行模式",
        @"lowpower":      @"低电量模式",
        @"playpause":     @"播放/暂停音乐",
        @"nexttrack":     @"下一首",
        @"prevtrack":     @"上一首",
        @"volup":         @"音量 +",
        @"voldown":       @"音量 −",
        @"mute":          @"静音",
        @"appswitcher":   @"App切换器（多任务）",
        @"camera":        @"相机",
        @"wlan":          @"无线局域网",
        @"cellular":          @"蜂窝网络开关",
    };
    return map[act] ?: act;
}

// 各手势类型允许的动作
static NSArray *MGActsSingle(void) { return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home",
    @"wifi", @"wlan", @"cellular", @"bluetooth", @"airplane", @"lowpower",
    @"playpause", @"nexttrack", @"prevtrack", @"volup", @"voldown", @"mute", @"appswitcher", @"camera", @"settingspanel"]; }
static NSArray *MGActsDouble(void) { return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home",
    @"wifi", @"wlan", @"cellular", @"bluetooth", @"airplane", @"lowpower",
    @"playpause", @"nexttrack", @"prevtrack", @"volup", @"voldown", @"mute", @"appswitcher", @"camera"]; }
static NSArray *MGActsSwipe(void)  { return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home",
    @"wifi", @"wlan", @"cellular", @"bluetooth", @"airplane", @"lowpower",
    @"playpause", @"nexttrack", @"prevtrack", @"volup", @"voldown", @"mute", @"appswitcher", @"camera"]; }

#pragma mark - 选择子页面基类

@interface MGActionPickerController : PSListController
+ (NSString *)mgKey;
+ (NSString *)mgTitle;
+ (NSArray *)mgActions;
+ (NSString *)mgAppPickerClass;
- (id)mgSwitchValue:(PSSpecifier *)spec;
- (void)mgPickSwitch:(id)value specifier:(PSSpecifier *)spec;
- (NSString *)currentValue;
- (id)mgAppCurrentValue:(PSSpecifier *)spec;
@end

@implementation MGActionPickerController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = [[self class] mgTitle];
}

- (NSArray *)specifiers
{
    if (!_specifiers) {
        NSMutableArray *m = [NSMutableArray array];

        PSSpecifier *g = MGNewSpec(self, @"选择动作", nil, NULL, NULL, nil, PSGroupCell);
        [g setProperty:@"选择动作" forKey:@"label"];
        [g setProperty:@"单选：打开一项即选中（其余自动关闭），立即生效；把当前项关掉 = 改为「无」。返回后主页面右侧会显示当前选中项。\n要打开某个 App，点最上面的「打开应用…」。返回后主页面右侧会显示当前选中项。" forKey:@"footerText"];
        [m addObject:g];

        // ===== 打开应用: 置顶入口 (按手势独立的应用选择页, 搜索+图标+单选) =====
        PSSpecifier *appRow = MGNewSpec(self, @"打开应用…", self,
            NULL, @selector(mgAppCurrentValue:), NSClassFromString([[self class] mgAppPickerClass]), PSLinkCell);
        [appRow setProperty:NSClassFromString([[self class] mgAppPickerClass]) forKey:@"detail"];
        [m addObject:appRow];

        // 当前选中的动作
        NSString *key = [[self class] mgKey];
        NSString *cur = [self currentValue];

        for (NSString *act in [[self class] mgActions]) {
            PSSpecifier *s = MGNewSpec(self, MGActionTitle(act), self,
                @selector(mgPickSwitch:specifier:), @selector(mgSwitchValue:), nil, PSSwitchCell);
            [s setProperty:act forKey:@"mgAction"];
            [m addObject:s];
        }

        // ===== 打开应用: 进入按手势独立的应用选择页 (搜索+图标+单选) =====
        _specifiers = [m copy];
    }
    return _specifiers;
}

// 「打开应用…」行右侧显示当前绑定的应用名 (未绑定则不显示)
- (id)mgAppCurrentValue:(PSSpecifier *)spec
{
    NSString *cur = [self currentValue];
    if ([cur hasPrefix:@"app:"]) return MGAppTitleForBid([cur substringFromIndex:4]);
    return nil;
}

// 开关状态: 当前动作 == 本行动作
- (NSString *)currentValue
{
    NSString *key = [[self class] mgKey];
    NSString *cur = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)MG_SUITE));
    if (![cur isKindOfClass:[NSString class]] || cur.length == 0) cur = @"none";
    return cur;
}

- (id)mgSwitchValue:(PSSpecifier *)spec
{
    return @([[self currentValue] isEqualToString:[spec propertyForKey:@"mgAction"]]);
}

// 单选: 打开一项写入手势键并刷新(其余自动关闭); 关掉当前项 → 变「无」
- (void)mgPickSwitch:(id)value specifier:(PSSpecifier *)spec
{
    NSString *act = [spec propertyForKey:@"mgAction"];
    if (!act.length) return;
    NSString *key = [[self class] mgKey];
    NSString *newVal = [value boolValue] ? act : @"none";
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFTypeRef)newVal, (__bridge CFStringRef)MG_SUITE);
    CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
    _specifiers = nil;
    [self reloadSpecifiers]; // 刷新所有行的开关状态 (单选互斥)
}

@end

#pragma mark - 每个手势一个子类 (声明编辑键/标题/允许动作, 免去传参依赖)

#define MG_PICKER_CLASS(CNAME, KEY, TITLE, ACTS, APPCLS) \
@interface CNAME : MGActionPickerController @end \
@implementation CNAME \
+ (NSString *)mgKey { return KEY; } \
+ (NSString *)mgTitle { return TITLE; } \
+ (NSArray *)mgActions { return ACTS; } \
+ (NSString *)mgAppPickerClass { return APPCLS; } \
@end

// 不分段模式 (左右耳朵共用)
MG_PICKER_CLASS(MGPickerSingleTap,  @"singleTap",  @"单击动作", MGActsSingle(), @"MGAppPickerSingleTap")
MG_PICKER_CLASS(MGPickerDoubleTap,  @"doubleTap",  @"双击动作", MGActsDouble(), @"MGAppPickerDoubleTap")
MG_PICKER_CLASS(MGPickerSwipeLeft,  @"swipeLeft",  @"左滑动作", MGActsSwipe(), @"MGAppPickerSwipeLeft")
// 分段模式 - 左段 (时间侧)
MG_PICKER_CLASS(MGPickerLSingleTap, @"left_singleTap",  @"左段·单击动作", MGActsSingle(), @"MGAppPickerLSingleTap")
MG_PICKER_CLASS(MGPickerLDoubleTap, @"left_doubleTap",  @"左段·双击动作", MGActsDouble(), @"MGAppPickerLDoubleTap")
MG_PICKER_CLASS(MGPickerLSwipeLeft, @"left_swipeLeft",  @"左段·左滑动作", MGActsSwipe(), @"MGAppPickerLSwipeLeft")
// 分段模式 - 右段 (电池信号侧)
MG_PICKER_CLASS(MGPickerRSingleTap, @"right_singleTap", @"右段·单击动作", MGActsSingle(), @"MGAppPickerRSingleTap")
MG_PICKER_CLASS(MGPickerRDoubleTap, @"right_doubleTap", @"右段·双击动作", MGActsDouble(), @"MGAppPickerRDoubleTap")
MG_PICKER_CLASS(MGPickerRSwipeLeft, @"right_swipeLeft", @"右段·左滑动作", MGActsSwipe(), @"MGAppPickerRSwipeLeft")
