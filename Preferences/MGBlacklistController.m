// MyGestures App黑名单子页面 v0.1.0
// 枚举已安装 App, 每行一个开关: 开 = 加入黑名单 (偏好键 bl_<bundleid>)
// tweak 侧在每个 App 进程内读同键判断, 黑名单内全部状态栏手势失效
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define MG_SUITE @"com.local.mygestures"

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

        PSSpecifier *g = [self preferenceSpecifierWithName:@"应用列表" target:nil
            set:NULL get:NULL detail:nil cell:PSGroupCell edit:0];
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
                        NSString *name = [app respondsToSelector:@selector(localizedDisplayName)] ? [app localizedDisplayName] : nil;
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
            PSSpecifier *s = [self preferenceSpecifierWithName:row[0] target:nil
                set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:)
                detail:nil cell:PSSwitchCell edit:0];
            [s setProperty:MG_SUITE forKey:@"defaults"];
            [s setProperty:[@"bl_" stringByAppendingString:row[1]] forKey:@"key"];
            [m addObject:s];
        }

        _specifiers = [m copy];
    }
    return _specifiers;
}

@end
