// MyGestures 打开应用选择页 v0.4.0
// 每个手势一个子类; 页面 = 搜索栏 + 应用列表(图标+单选开关)
// 应用范围: 苹果预装 App + App Store 沙盒应用 (过滤无图标的系统级程序)
// 绑定值格式: "app:<bundleid>", tweak 侧经内置 scheme 表 / 快捷指令桥接打开
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
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

#pragma mark - 应用枚举 (预装 + 沙盒, 过滤系统级)

// 应用显示名: 运行时按候选方法名取
static NSString *MGAppName2(id app)
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

// 从 App 包内读图标文件
static UIImage *MGIconFromBundlePath(NSString *appPath)
{
    if (!appPath.length) return nil;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
    if (![info isKindOfClass:[NSDictionary class]]) return nil;
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
    if (!name.length) return nil;
    for (NSString *cand in @[[name stringByAppendingPathExtension:@"png"],
                             [NSString stringWithFormat:@"%@@3x.png", name],
                             [NSString stringWithFormat:@"%@@2x.png", name],
                             name]) {
        UIImage *img = [UIImage imageWithContentsOfFile:[appPath stringByAppendingPathComponent:cand]];
        if (img) return img;
    }
    return nil;
}

// 图标统一缩放到 29pt (适配列表行高, 避免撑坏排版)
static UIImage *MGIconResized(UIImage *img)
{
    if (!img || img.size.width <= 29.0) return img;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(29, 29)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [img drawInRect:CGRectMake(0, 0, 29, 29)];
    }];
}

// 全量应用行: @[名称, bundleid, 包路径] — 过滤掉无图标的系统级程序
// (黑名单页共用本函数, 保证两边列表一致)
NSArray *MGAppRows(void)
{
    static NSArray *cached = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *rows = [NSMutableArray array];
        @try {
            Class wsClass = objc_getClass("LSApplicationWorkspace");
            if (!wsClass) { cached = rows; return; }
            id ws = ((id (*)(id, SEL))objc_msgSend)(wsClass, @selector(defaultWorkspace));
            NSArray *apps = nil;
            for (NSString *selName in @[@"allInstalledApplications", @"allInstalledApps", @"installedApps"]) {
                SEL s = NSSelectorFromString(selName);
                if ([ws respondsToSelector:s]) {
                    apps = ((NSArray *(*)(id, SEL))objc_msgSend)(ws, s);
                    if (apps.count > 0) break;
                }
            }
            for (id app in apps ?: @[]) {
                @try {
                    NSString *bid = [app respondsToSelector:@selector(bundleIdentifier)] ? [app bundleIdentifier] : nil;
                    if (!bid.length) continue;
                    NSString *name = MGAppName2(app) ?: bid;
                    // 系统级过滤: applicationType == User (App Store 沙盒) 直接保留;
                    // System 类型保留有图标的 (苹果预装可见 App, 如 相机/计算器), 无图标的是系统级程序 → 排除
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
                    BOOL hasIcon = MGIconFromBundlePath(bundlePath) != nil;
                    BOOL isUser = [appType isEqualToString:@"User"];
                    BOOL isPreloadedSystem = [appType isEqualToString:@"System"] && hasIcon;
                    if (!isUser && !isPreloadedSystem) continue; // 系统级程序 → 排除
                    [rows addObject:@[name, bid, bundlePath ?: @""]];
                } @catch (NSException *e) { /* 跳过异常项 */ }
            }
        } @catch (NSException *e) {
            NSLog(@"[MyGestures] 枚举应用失败: %@", e);
        }
        [rows sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
            return [a[0] compare:b[0] options:NSNumericSearch | NSCaseInsensitiveSearch];
        }];
        cached = [rows copy];
    });
    return cached;
}

// bid → 显示名 (找不到返回 bid 本身)
NSString *MGAppTitleForBid(NSString *bid)
{
    for (NSArray *r in MGAppRows()) if ([r[1] isEqualToString:bid]) return r[0];
    return bid;
}

#pragma mark - 选择页基类

@interface MGAppPickerController : PSListController <UISearchBarDelegate>
{
    NSMutableDictionary *_iconCache;
    NSString *_searchText;
    BOOL _searchInstalled;
}
+ (NSString *)mgKey;
- (id)mgAppSwitchValue:(PSSpecifier *)spec;
- (void)mgAppPickSwitch:(id)v specifier:(PSSpecifier *)spec;
@end

@implementation MGAppPickerController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = @"打开应用";
    if (!_searchInstalled) {
        [self installSearchBar];
        _searchInstalled = YES;
    }
}

- (void)installSearchBar
{
    @try {
        UITableView *tv = nil;
        if ([self respondsToSelector:@selector(table)]) {
            tv = ((id (*)(id, SEL))objc_msgSend)(self, @selector(table));
        }
        if (!tv) return;
        CGFloat w = tv.frame.size.width;
        if (w < 100.0) w = 340.0;
        UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
        bar.placeholder = @"搜索应用";
        bar.delegate = self;
        tv.tableHeaderView = bar;
    } @catch (NSException *e) {}
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    _searchText = [searchText copy];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

- (NSString *)currentValue
{
    NSString *key = [[self class] mgKey];
    NSString *v = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key, (__bridge CFStringRef)MG_SUITE));
    return ([v isKindOfClass:[NSString class]]) ? v : @"none";
}

- (NSArray *)specifiers
{
    if (!_specifiers) {
        NSMutableArray *m = [NSMutableArray array];

        PSSpecifier *g = MGNewSpec(self, @"选择要打开的应用", nil, NULL, NULL, nil, PSGroupCell);
        [g setProperty:@"选择要打开的应用" forKey:@"label"];
        [g setProperty:@"单选：打开一项即选中（其余自动关闭）。「无」= 清除该手势的应用绑定。\n常用 App 直接生效；其他 App 可在快捷指令里建「打开App」后经 我的链接 绑定。" forKey:@"footerText"];
        [m addObject:g];

        NSString *cur = [self currentValue];
        NSString *q = [_searchText lowercaseString];

        for (NSArray *row in MGAppRows()) {
            if (q.length > 0) {
                NSString *name = [row[0] lowercaseString];
                NSString *bid = [row[1] lowercaseString];
                if (![name containsString:q] && ![bid containsString:q]) continue;
            }
            PSSpecifier *s = MGNewSpec(self, row[0], self,
                @selector(mgAppPickSwitch:specifier:), @selector(mgAppSwitchValue:), nil, PSSwitchCell);
            [s setProperty:[@"app:" stringByAppendingString:row[1]] forKey:@"mgAction"];
            [m addObject:s];
        }

        _specifiers = [m copy];
    }
    return _specifiers;
}

// 开关状态: 当前绑定值 == 本行
- (id)mgAppSwitchValue:(PSSpecifier *)spec
{
    NSString *act = [spec propertyForKey:@"mgAction"];
    return @([[self currentValue] isEqualToString:act]);
}

// 单选: 打开一项写入绑定, 其余自动关闭; 关掉 = 清除绑定
- (void)mgAppPickSwitch:(id)v specifier:(PSSpecifier *)spec
{
    NSString *act = [spec propertyForKey:@"mgAction"];
    if (!act.length) return;
    NSString *key = [[self class] mgKey];
    NSString *newVal = [v boolValue] ? act : @"none";
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFTypeRef)newVal, (__bridge CFStringRef)MG_SUITE);
    CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
    _specifiers = nil;
    [self reloadSpecifiers];
}

// 在系统生成的开关 cell 上补画 App 图标
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    struct objc_super sup = { self, class_getSuperclass([MGAppPickerController class]) };
    UITableViewCell *cell = ((id (*)(struct objc_super *, SEL, id, id))objc_msgSendSuper)(
        &sup, @selector(tableView:cellForRowAtIndexPath:), tableView, indexPath);
    @try {
        NSString *text = cell.textLabel.text;
        if (text.length) {
            for (NSArray *row in MGAppRows()) {
                if ([row[0] isEqualToString:text]) {
                    NSString *bid = row[1];
                    UIImage *img = _iconCache[bid];
                    if (!img) {
                        img = MGIconResized(MGIconFromBundlePath(row[2]));
                        if (!img) img = [UIImage new];
                        _iconCache[bid] = img;
                    }
                    if (img.size.width > 0) {
                        cell.imageView.image = img;
                        cell.imageView.layer.cornerRadius = 6.0;
                        cell.imageView.clipsToBounds = YES;
                    }
                    break;
                }
            }
        }
    } @catch (NSException *e) {}
    return cell;
}

@end

#pragma mark - 每个手势一个子类

#define MG_APP_PICKER_CLASS(CNAME, KEY) \
@interface CNAME : MGAppPickerController @end \
@implementation CNAME \
+ (NSString *)mgKey { return KEY; } \
@end

MG_APP_PICKER_CLASS(MGAppPickerSingleTap,  @"singleTap")
MG_APP_PICKER_CLASS(MGAppPickerDoubleTap,  @"doubleTap")
MG_APP_PICKER_CLASS(MGAppPickerSwipeLeft,  @"swipeLeft")
MG_APP_PICKER_CLASS(MGAppPickerLSingleTap, @"left_singleTap")
MG_APP_PICKER_CLASS(MGAppPickerLDoubleTap, @"left_doubleTap")
MG_APP_PICKER_CLASS(MGAppPickerLSwipeLeft, @"left_swipeLeft")
MG_APP_PICKER_CLASS(MGAppPickerRSingleTap, @"right_singleTap")
MG_APP_PICKER_CLASS(MGAppPickerRDoubleTap, @"right_doubleTap")
MG_APP_PICKER_CLASS(MGAppPickerRSwipeLeft, @"right_swipeLeft")
