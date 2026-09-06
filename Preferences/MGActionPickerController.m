// MyGestures 动作选择子页面 v0.1.3
// 主页面每个手势行 (PSLinkCell) 推入对应子类; 子页面每行一个动作 (PSButtonCell),
// 点选立即写入 CFPreferences 并自动返回上一页; 右侧当前值由主页面 get: 刷新
// 注: 构造走 PSSpecifier preferenceSpecifierNamed: (真机 frida 反射实锤的唯一可用选择器)
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define MG_SUITE @"com.local.mygestures"

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
    };
    return map[act] ?: act;
}

// 各手势类型允许的动作 (与原型一致: 左滑无"返回主屏幕", 双击/左滑无"打开设置面板")
static NSArray *MGActsSingle(void) { return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home", @"settingspanel"]; }
static NSArray *MGActsDouble(void) { return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring", @"home"]; }
static NSArray *MGActsSwipe(void)  { return @[@"none", @"lock", @"screenshot", @"flashlight", @"respring"]; }

#pragma mark - 选择子页面基类

@interface MGActionPickerController : PSListController
+ (NSString *)mgKey;
+ (NSString *)mgTitle;
+ (NSArray *)mgActions;
- (void)mgPick:(PSSpecifier *)spec;
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
        [g setProperty:@"点选任意动作立即生效并自动返回上一页；主页面右侧会同步显示当前选中项。" forKey:@"footerText"];
        [m addObject:g];

        for (NSString *act in [[self class] mgActions]) {
            PSSpecifier *s = MGNewSpec(self, MGActionTitle(act), self,
                @selector(mgPick:), NULL, nil, PSButtonCell);
            [s setProperty:act forKey:@"mgAction"];
            [m addObject:s];
        }

        _specifiers = [m copy];
    }
    return _specifiers;
}

- (void)mgPick:(PSSpecifier *)spec
{
    if (!spec) return;
    NSString *act = [spec propertyForKey:@"mgAction"];
    if (!act.length) return;
    NSString *key = [[self class] mgKey];
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFTypeRef)act, (__bridge CFStringRef)MG_SUITE);
    CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.navigationController popViewControllerAnimated:YES];
    });
}

@end

#pragma mark - 每个手势一个子类 (声明编辑键/标题/允许动作, 免去传参依赖)

#define MG_PICKER_CLASS(CNAME, KEY, TITLE, ACTS) \
@interface CNAME : MGActionPickerController @end \
@implementation CNAME \
+ (NSString *)mgKey { return KEY; } \
+ (NSString *)mgTitle { return TITLE; } \
+ (NSArray *)mgActions { return ACTS; } \
@end

// 不分段模式 (左右耳朵共用)
MG_PICKER_CLASS(MGPickerSingleTap,  @"singleTap",  @"单击动作", MGActsSingle())
MG_PICKER_CLASS(MGPickerDoubleTap,  @"doubleTap",  @"双击动作", MGActsDouble())
MG_PICKER_CLASS(MGPickerSwipeLeft,  @"swipeLeft",  @"左滑动作", MGActsSwipe())
// 分段模式 - 左段 (时间侧)
MG_PICKER_CLASS(MGPickerLSingleTap, @"left_singleTap",  @"左段·单击动作", MGActsSingle())
MG_PICKER_CLASS(MGPickerLDoubleTap, @"left_doubleTap",  @"左段·双击动作", MGActsDouble())
MG_PICKER_CLASS(MGPickerLSwipeLeft, @"left_swipeLeft",  @"左段·左滑动作", MGActsSwipe())
// 分段模式 - 右段 (电池信号侧)
MG_PICKER_CLASS(MGPickerRSingleTap, @"right_singleTap", @"右段·单击动作", MGActsSingle())
MG_PICKER_CLASS(MGPickerRDoubleTap, @"right_doubleTap", @"右段·双击动作", MGActsDouble())
MG_PICKER_CLASS(MGPickerRSwipeLeft, @"right_swipeLeft", @"右段·左滑动作", MGActsSwipe())
