// MyGestures 设置面板主控制器 v0.1.0
// 功能: 顶部状态栏示意图(绿耳朵/红遮挡区) + 分区模式条件显隐 + 全局设置项
// 面板沿用「系统-设置出现面板菜单的方法」已验证方案:
//   只 import <Preferences/Preferences.h>、PSListController 子类
// 注: 14.5 SDK 头文件未声明 preferenceSpecifierWithName:... , 用 objc_msgSend 动态调用
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define MG_SUITE @"com.local.mygestures"

@class MGBlacklistController;

#pragma mark - 规格构建辅助 (SDK 头文件缺声明, 走 msgSend)

static id MGNewSpec(id ctrl, NSString *name, id target, SEL set, SEL get, id detail, NSInteger cell)
{
    SEL sel = NSSelectorFromString(@"preferenceSpecifierWithName:target:set:get:detail:cell:edit:");
    id (*msg)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger) =
        (id (*)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger))objc_msgSend;
    return msg(ctrl, sel, name, target, set, get, detail, cell, 0);
}

#pragma mark - 动作选项表

// 单击可用全部动作(含"打开设置面板")
static NSArray *MGValuesSingle(void) {
    return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home", @"settingspanel"];
}
// 双击/左滑不含"打开设置面板"
static NSArray *MGValuesDouble(void) {
    return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home"];
}
// 左滑不含"返回主屏幕"(与原型一致)
static NSArray *MGValuesSwipe(void) {
    return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring"];
}
static NSArray *MGTitles(NSArray *values) {
    NSDictionary *map = @{
        @"none":          @"无",
        @"lock":          @"锁屏",
        @"screenshot":    @"截屏",
        @"flashlight":    @"手电筒开关",
        @"respring":      @"Respring注销",
        @"home":          @"返回主屏幕",
        @"settingspanel": @"打开本工具设置面板",
    };
    NSMutableArray *t = [NSMutableArray array];
    for (NSString *v in values) [t addObject:map[v] ?: v];
    return t;
}

#pragma mark - 规格构建

// 把出厂默认值固化进偏好, 让面板首次打开就显示默认选中项 (tweak 侧同值, 两侧一致)
static void MGEnsureDefault(NSString *key, id value)
{
    if (!CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)MG_SUITE)) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFTypeRef)value, (__bridge CFStringRef)MG_SUITE);
        CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
    }
}

static PSSpecifier *MGGroup(id ctrl, NSString *label, NSString *footer)
{
    PSSpecifier *s = MGNewSpec(ctrl, label, nil, NULL, NULL, nil, PSGroupCell);
    [s setProperty:label forKey:@"label"];
    if (footer) [s setProperty:footer forKey:@"footerText"];
    return s;
}

static PSSpecifier *MGSwitch(id ctrl, NSString *name, NSString *key)
{
    PSSpecifier *s = MGNewSpec(ctrl, name, nil,
        @selector(setPreferenceValue:specifier:), @selector(readPreferenceValue:), nil, PSSwitchCell);
    [s setProperty:MG_SUITE forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    return s;
}

static PSSpecifier *MGSelect(id ctrl, NSString *name, NSString *key, NSString *def, NSArray *values)
{
    PSSpecifier *s = MGNewSpec(ctrl, name, nil,
        @selector(setPreferenceValue:specifier:), @selector(readPreferenceValue:), nil, PSListItemCell);
    [s setProperty:MG_SUITE forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:def forKey:@"default"];
    [s setProperty:values forKey:@"validValues"];
    [s setProperty:MGTitles(values) forKey:@"validTitles"];
    return s;
}

static PSSpecifier *MGSlider(id ctrl, NSString *name, NSString *key)
{
    PSSpecifier *s = MGNewSpec(ctrl, name, nil,
        @selector(setPreferenceValue:specifier:), @selector(readPreferenceValue:), nil, PSSliderCell);
    [s setProperty:MG_SUITE forKey:@"defaults"];
    [s setProperty:key forKey:@"key"];
    [s setProperty:@0.20 forKey:@"min"];
    [s setProperty:@0.50 forKey:@"max"];
    [s setProperty:@0.32 forKey:@"default"];
    [s setProperty:@YES forKey:@"isContinuous"];
    [s setProperty:@YES forKey:@"showValueLabel"];
    return s;
}

#pragma mark - 主控制器

@interface MGSettingsController : PSListController
- (id)readSplitMode:(PSSpecifier *)spec;
- (void)setSplitMode:(id)value specifier:(PSSpecifier *)spec;
@end

@implementation MGSettingsController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = @"我的手势 0.1.0";
    [self attachDiagramHeader];
}

- (NSArray *)specifiers
{
    if (!_specifiers) {
        // 固化出厂默认 (面板首次打开即可见): 分区关/单击无/双击锁屏/左滑手电筒/锁屏开/震动开/0.32s
        MGEnsureDefault(@"splitMode", @NO);
        MGEnsureDefault(@"singleTap", @"none");
        MGEnsureDefault(@"doubleTap", @"lock");
        MGEnsureDefault(@"swipeLeft", @"flashlight");
        MGEnsureDefault(@"lockScreenEnabled", @YES);
        MGEnsureDefault(@"hapticsEnabled", @YES);
        MGEnsureDefault(@"tapInterval", @0.32);

        NSMutableArray *m = [NSMutableArray array];

        id splitVal = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("splitMode"), (__bridge CFStringRef)MG_SUITE));
        BOOL splitOn = [splitVal isKindOfClass:[NSNumber class]] ? [splitVal boolValue] : NO;

        // ===== 分区模式开关 (切换后重建列表) =====
        PSSpecifier *split = MGNewSpec(self, @"启用状态栏左右分区", self,
            @selector(setSplitMode:specifier:), @selector(readSplitMode:), nil, PSSwitchCell);
        [m addObject:MGGroup(self, @"分区模式", @"关闭：左右耳朵共用同一套手势配置。\n开启：左段（时间侧）与右段（电池信号侧）完全独立配置，互不干扰。")];
        [m addObject:split];

        if (!splitOn) {
            // ===== 模式1: 左右耳朵共用 =====
            [m addObject:MGGroup(self, @"公共手势（左右耳朵共用）", @"手势选「无」代表单独禁用该手势，无需关闭整个插件。\n长按、三击、上滑、下滑始终交给系统，不占用。")];
            [m addObject:MGSelect(self, @"单击", @"singleTap", @"none", MGValuesSingle())];
            [m addObject:MGSelect(self, @"双击", @"doubleTap", @"lock", MGValuesDouble())];
            [m addObject:MGSelect(self, @"左滑", @"swipeLeft", @"flashlight", MGValuesSwipe())];
        } else {
            // ===== 模式2: 左右分段独立 =====
            [m addObject:MGGroup(self, @"状态栏‑左段｜时间侧", @"刘海/灵动岛左侧的耳朵区域，只在此区域内生效。")];
            [m addObject:MGSelect(self, @"单击", @"left_singleTap", @"none", MGValuesSingle())];
            [m addObject:MGSelect(self, @"双击", @"left_doubleTap", @"lock", MGValuesDouble())];
            [m addObject:MGSelect(self, @"左滑", @"left_swipeLeft", @"flashlight", MGValuesSwipe())];

            [m addObject:MGGroup(self, @"状态栏‑右段｜电池信号侧", @"刘海/灵动岛右侧的耳朵区域（信号/Wi‑Fi/电池），只在此区域内生效。")];
            [m addObject:MGSelect(self, @"单击", @"right_singleTap", @"none", MGValuesSingle())];
            [m addObject:MGSelect(self, @"双击", @"right_doubleTap", @"lock", MGValuesDouble())];
            [m addObject:MGSelect(self, @"左滑", @"right_swipeLeft", @"flashlight", MGValuesSwipe())];
        }

        // ===== 全局设置 =====
        [m addObject:MGGroup(self, @"全局设置", @"所有设置修改即时生效，无需 Respring。\n黑名单 App 内全部状态栏手势失效；刘海/灵动岛本体触摸始终直接忽略。")];
        [m addObject:MGSwitch(self, @"锁屏界面启用手势", @"lockScreenEnabled")];
        [m addObject:MGSwitch(self, @"手势震动反馈", @"hapticsEnabled")];
        [m addObject:MGSlider(self, @"双击识别间隔(秒)", @"tapInterval")];
        [m addObject:MGGroup(self, @"应用管理", nil)];
        PSSpecifier *bl = MGNewSpec(self, @"App黑名单", self, NULL, NULL,
            NSClassFromString(@"MGBlacklistController"), PSLinkCell);
        [m addObject:bl];

        _specifiers = [m copy];
    }
    return _specifiers;
}

- (id)readSplitMode:(PSSpecifier *)spec
{
    id v = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("splitMode"), (__bridge CFStringRef)MG_SUITE));
    return @([v isKindOfClass:[NSNumber class]] ? [v boolValue] : NO);
}

- (void)setSplitMode:(id)value specifier:(PSSpecifier *)spec
{
    CFPreferencesSetAppValue(CFSTR("splitMode"),
        [value boolValue] ? kCFBooleanTrue : kCFBooleanFalse,
        (__bridge CFStringRef)MG_SUITE);
    CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
    _specifiers = nil;
    [self reloadSpecifiers];
}

#pragma mark - 顶部示意图 (绿耳朵 / 红遮挡区)

- (void)attachDiagramHeader
{
    @try {
        UITableView *tv = nil;
        if ([self respondsToSelector:@selector(table)]) {
            tv = ((id (*)(id, SEL))objc_msgSend)(self, @selector(table));
        }
        if (!tv || tv.tableHeaderView) return;

        CGFloat w = tv.frame.size.width;
        if (w < 100.0) w = 340.0;
        CGFloat cardH = 148.0;
        UIView *hv = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, cardH + 12)];

        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 8, w - 32, cardH)];
        card.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.22];
        card.layer.cornerRadius = 12;
        [hv addSubview:card];

        // 状态栏条: 左耳(绿) / 遮挡区(红) / 右耳(绿)
        CGFloat bx = 12, by = 12, bw = card.frame.size.width - 24, bh = 44;
        CGFloat earW = bw * 0.38, midW = bw * 0.24;
        CGFloat px = bx;
        for (NSInteger i = 0; i < 3; i++) {
            CGFloat segW = (i == 1) ? midW : earW;
            UIView *seg = [[UIView alloc] initWithFrame:CGRectMake(px, by, segW, bh)];
            seg.backgroundColor = [UIColor clearColor];
            seg.layer.borderWidth = 2.0;
            seg.layer.cornerRadius = 4.0;
            seg.layer.borderColor = (i == 1)
                ? [UIColor systemRedColor].CGColor
                : [UIColor systemGreenColor].CGColor;
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, segW, 28)];
            lb.textAlignment = NSTextAlignmentCenter;
            lb.font = [UIFont systemFontOfSize:12];
            lb.textColor = UIColor.whiteColor;
            lb.text = (i == 0) ? @"19:38" : ((i == 1) ? @"🔴" : @"📶🔋");
            [seg addSubview:lb];
            [card addSubview:seg];
            px += segW;
        }

        // 三个区域的箭头文字标注
        NSArray *notes = @[
            @"↓ 🟢左耳朵\n单击/双击/左滑",
            @"↓ 🔴无效区\n刘海/灵动岛 触摸忽略",
            @"↓ 🟢右耳朵\n单击/双击/左滑",
        ];
        CGFloat nx = bx;
        for (NSInteger i = 0; i < 3; i++) {
            CGFloat segW = (i == 1) ? midW : earW;
            UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(nx, by + bh + 8, segW, 52)];
            lb.textAlignment = NSTextAlignmentCenter;
            lb.font = [UIFont systemFontOfSize:10];
            lb.numberOfLines = 3;
            lb.textColor = (i == 1) ? [UIColor systemRedColor] : [UIColor systemGreenColor];
            lb.text = notes[i];
            [card addSubview:lb];
            nx += segW;
        }

        // 底部提示: 下滑交给系统
        UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(bx, cardH - 26, bw, 20)];
        tip.textAlignment = NSTextAlignmentCenter;
        tip.font = [UIFont systemFontOfSize:9];
        tip.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        tip.numberOfLines = 2;
        tip.text = @"向下滑动交给系统，保留通知中心、控制中心原生逻辑，兼容各类控制中心插件";
        [card addSubview:tip];

        tv.tableHeaderView = hv;
    } @catch (NSException *e) {
        NSLog(@"[MyGestures] 示意图构建失败(不影响设置功能): %@", e);
    }
}

@end
