// MyGestures App黑名单子页面 v0.1.0
// 枚举已安装 App, 每行一个开关: 开 = 加入黑名单 (偏好键 bl_<bundleid>)
// tweak 侧在每个 App 进程内读同键判断, 黑名单内全部状态栏手势失效
// 注: 14.5 SDK 头文件未声明 preferenceSpecifierWithName:... , 用 objc_msgSend 动态调用
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define MG_SUITE @"com.local.mygestures"

static id MGNewSpec(id ctrl, NSString *name, id target, SEL set, SEL get, id detail, NSInteger cell)
{
    SEL sel = NSSelectorFromString(@"preferenceSpecifierWithName:target:set:get:detail:cell:edit:");
    id (*msg)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger) =
        (id (*)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger))objc_msgSend;
    return msg(ctrl, sel, name, target, set, get, detail, cell, 0);
}

// 应用显示名: 14.5 SDK 头文件未声明 localizedDisplayName, 运行时按候选方法名取
static NSString *MGAppName(id app)
{
    for (NSString *selName in @[@"localizedDisplayName", @"localizedName"]) {
        SEL s = NSSelectorFromString(selName);
        if ([app respondsToSelector:s]) {
            NSString *n = ((NSString *(*)(id, SEL))objc_msgSend)(app, s);
            if (n.length) return n;
        }
    }
    return nil;
}

@interface MGBlacklistController : PSListController
@end

@implementation MGBlacklistController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = @"App黑名单";
}

- (NSArray *)specifiers
{
    if (!_specifiers) {
        NSMutableArray *m = [NSMutableArray array];

        PSSpecifier *g = MGNewSpec(self, @"应用列表", nil, NULL, NULL, nil, PSGroupCell);
        [g setProperty:@"应用列表" forKey:@"label"];
        [g setProperty:@"开关打开 = 加入黑名单，该 App 内全部状态栏手势失效。默认全部关闭（都可用）。\n主界面（SpringBoard）不受黑名单影响。" forKey:@"footerText"];
        [m addObject:g];

        // 枚举已安装应用: LSApplicationWorkspace allInstalledApps
        NSMutableArray *rows = [NSMutableArray array];
        @try {
            Class wsClass = objc_getClass("LSApplicationWorkspace");
            if (wsClass) {
                id ws = ((id (*)(id, SEL))objc_msgSend)(wsClass, @selector(defaultWorkspace));
                NSArray *apps = ws ? ((NSArray *(*)(id, SEL))objc_msgSend)(ws, @selector(allInstalledApps)) : nil;
                for (id app in apps) {
                    @try {
                        NSString *bid = [app respondsToSelector:@selector(bundleIdentifier)] ? [app bundleIdentifier] : nil;
                        NSString *name = bid.length ? MGAppName(app) : nil;
                        if (bid.length && name.length) [rows addObject:@[name, bid]];
                    } @catch (NSException *e) { /* 跳过异常项 */ }
                }
            }
        } @catch (NSException *e) {
            NSLog(@"[MyGestures] 枚举应用失败: %@", e);
        }

        [rows sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
            return [a[0] compare:b[0] options:NSNumericSearch | NSCaseInsensitiveSearch];
        }];

        for (NSArray *row in rows) {
            PSSpecifier *s = MGNewSpec(self, row[0], nil,
                @selector(setPreferenceValue:specifier:), @selector(readPreferenceValue:), nil, PSSwitchCell);
            [s setProperty:MG_SUITE forKey:@"defaults"];
            [s setProperty:[@"bl_" stringByAppendingString:row[1]] forKey:@"key"];
            [m addObject:s];
        }

        _specifiers = [m copy];
    }
    return _specifiers;
}

@end
