// MyGestures App黑名单子页面 v0.3.0
// 枚举已安装 App (16.6: allInstalledApplications), 每行开关 + App图标 + 顶部搜索栏
// 开关打开 = 加入黑名单 (偏好键 bl_<bundleid>), tweak 侧同键判断
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

// 应用显示名: 运行时按候选方法名取 (14.5 SDK 头文件未声明 localizedDisplayName)
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

// 从 App 包内读图标文件 (Info.plist → CFBundleIcons → CFBundleIconFiles)
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

NSArray *MGAppRows(void); // 在 MGAppPickerController.m 中实现 (预装+沙盒, 已过滤系统级)

@interface MGBlacklistController : PSListController <UISearchBarDelegate>
{
    NSArray *_rows;          // @[ @[名称, 包id, 包路径], ... ] 全量
    NSMutableDictionary *_iconCache; // bid → UIImage
    NSString *_searchText;
    BOOL _searchBarInstalled;
}
@end

@implementation MGBlacklistController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = @"App黑名单";
    if (!_searchBarInstalled) {
        [self installSearchBar];
        _searchBarInstalled = YES;
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
        bar.barStyle = UIBarStyleDefault;
        tv.tableHeaderView = bar;
    } @catch (NSException *e) {
        NSLog(@"[MyGestures] 搜索栏安装失败: %@", e);
    }
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

- (NSArray *)allRows
{
    if (!_rows) {
        // 与「打开应用」选择页共用同一份过滤列表: 苹果预装 + App Store 沙盒应用, 无系统级程序
        _rows = [MGAppRows() copy];
    }
    return _rows;
}

// 图标统一缩放到 29pt (适配列表行高)
static UIImage *MGIconResized(UIImage *img)
{
    if (!img || img.size.width <= 29.0) return img;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(29, 29)];
    img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [img drawInRect:CGRectMake(0, 0, 29, 29)];
    }];
    return img;
}

- (UIImage *)iconForRow:(NSArray *)row
{
    NSString *bid = row[1];
    UIImage *img = _iconCache[bid];
    if (img) return img;
    img = MGIconResized(MGIconFromBundlePath(row[2]));
    if (!img) img = [UIImage new]; // 占位, 避免重复读盘
    _iconCache[bid] = img;
    return img;
}

- (NSArray *)specifiers
{
    if (!_specifiers) {
        NSMutableArray *m = [NSMutableArray array];

        PSSpecifier *g = MGNewSpec(self, @"应用列表", nil, NULL, NULL, nil, PSGroupCell);
        [g setProperty:@"应用列表" forKey:@"label"];
        [g setProperty:@"开关打开 = 加入黑名单，该 App 内全部状态栏手势失效。默认全部关闭（都可用）。\n主界面（SpringBoard）不受黑名单影响。" forKey:@"footerText"];
        [m addObject:g];

        NSString *q = [_searchText lowercaseString];
        for (NSArray *row in [self allRows]) {
            if (q.length > 0) {
                NSString *name = [row[0] lowercaseString];
                NSString *bid = [row[1] lowercaseString];
                if (![name containsString:q] && ![bid containsString:q]) continue;
            }
            PSSpecifier *s = MGNewSpec(self, row[0], self,
                @selector(setPreferenceValue:specifier:), @selector(readPreferenceValue:), nil, PSSwitchCell);
            [s setProperty:MG_SUITE forKey:@"defaults"];
            [s setProperty:[@"bl_" stringByAppendingString:row[1]] forKey:@"key"];
            [m addObject:s];
        }

        _specifiers = [m copy];
    }
    return _specifiers;
}

// 在系统生成的开关 cell 上补画 App 图标 (行文本匹配到行模型)
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    struct objc_super sup = { self, class_getSuperclass([MGBlacklistController class]) };
    UITableViewCell *cell = ((id (*)(struct objc_super *, SEL, id, id))objc_msgSendSuper)(
        &sup, @selector(tableView:cellForRowAtIndexPath:), tableView, indexPath);
    @try {
        NSString *text = cell.textLabel.text;
        if (text.length) {
            for (NSArray *row in [self allRows]) {
                if ([row[0] isEqualToString:text]) {
                    UIImage *img = [self iconForRow:row];
                    if (img && img.size.width > 0) {
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
