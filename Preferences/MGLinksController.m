// MyGestures 我的链接管理页 v0.2.0
// 8 个预设槽位, 每个槽位 = 名称 + 网址 两行可编辑文本 (PSEditTextCell)
// 存储: 偏好键 links = 数组 [ {n:名称, u:网址}, ... ]
// 手势选择页里「打开链接」分组会列出全部已填名称; 清空名称即视为删除该条
// 支持任意 URL scheme: shortcuts://run-shortcut?name=xx (跑捷径) / weixin:// (微信) / https:// ...
#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#define MG_SUITE @"com.local.mygestures"
#define MG_LINK_SLOTS 8

static id MGNewSpec(id ctrl, NSString *name, id target, SEL set, SEL get, id detail, NSInteger cell)
{
    SEL sel = NSSelectorFromString(@"preferenceSpecifierNamed:target:set:get:detail:cell:edit:");
    id (*msg)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger) =
        (id (*)(id, SEL, NSString *, id, SEL, SEL, id, NSInteger, NSInteger))objc_msgSend;
    Class ps = objc_getClass("PSSpecifier");
    return msg(ps, sel, name, target, set, get, detail, cell, 0);
}

#pragma mark - 链接存储 (供选择页/tweak 共用的格式)

NSArray *MGLinksRead(void)
{
    NSArray *a = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("links"), (__bridge CFStringRef)MG_SUITE));
    return [a isKindOfClass:[NSArray class]] ? a : @[];
}

void MGLinksWrite(NSArray *a)
{
    CFPreferencesSetAppValue(CFSTR("links"), (__bridge CFTypeRef)a, (__bridge CFStringRef)MG_SUITE);
    CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
}

static NSString *MGLinkField(NSUInteger slot, NSString *field)
{
    NSArray *a = MGLinksRead();
    if (slot >= a.count) return @"";
    NSDictionary *d = a[slot];
    if (![d isKindOfClass:[NSDictionary class]]) return @"";
    NSString *v = d[field];
    return [v isKindOfClass:[NSString class]] ? v : @"";
}

static void MGLinkSetField(NSUInteger slot, NSString *field, NSString *value)
{
    NSMutableArray *a = [MGLinksRead() mutableCopy];
    while (a.count <= slot) [a addObject:[NSDictionary dictionary]];
    NSMutableDictionary *d = [a[slot] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (value.length > 0) d[field] = value; else [d removeObjectForKey:field];
    if (d.count == 0) [a removeObjectAtIndex:slot]; else a[slot] = d;
    MGLinksWrite(a);
}

// 首次打开预置常用模板 (只在 links 键完全不存在时写入一次)
static void MGLinksEnsureDefaults(void)
{
    CFPreferencesAppSynchronize((__bridge CFStringRef)MG_SUITE);
    if (CFPreferencesCopyAppValue(CFSTR("links"), (__bridge CFStringRef)MG_SUITE)) return;
    MGLinksWrite((@[
        @{ @"n": @"运行快捷指令", @"u": @"shortcuts://run-shortcut?name=快捷指令名称" },
        @{ @"n": @"微信", @"u": @"weixin://" },
        @{ @"n": @"支付宝", @"u": @"alipay://" },
        @{ @"n": @"打开相机", @"u": @"camera://" },
    ]));
}

#pragma mark - 主页面

@interface MGLinksController : PSListController
@end

@implementation MGLinksController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.title = @"我的链接";
}

// 槽位字段读写: 生成 8 槽 × 名称/网址 的 get/set (宏展开, 免运行时拼 selector)
#define MG_LINK_CELL(I) \
- (id)mgLink##I##NameGet:(PSSpecifier *)spec { return MGLinkField(I, @"n"); } \
- (void)mgLink##I##NameSet:(id)v specifier:(PSSpecifier *)spec { MGLinkSetField(I, @"n", [v isKindOfClass:[NSString class]] ? v : @""); } \
- (id)mgLink##I##URLGet:(PSSpecifier *)spec { return MGLinkField(I, @"u"); } \
- (void)mgLink##I##URLSet:(id)v specifier:(PSSpecifier *)spec { MGLinkSetField(I, @"u", [v isKindOfClass:[NSString class]] ? v : @""); }

MG_LINK_CELL(0) MG_LINK_CELL(1) MG_LINK_CELL(2) MG_LINK_CELL(3)
MG_LINK_CELL(4) MG_LINK_CELL(5) MG_LINK_CELL(6) MG_LINK_CELL(7)

- (NSArray *)specifiers
{
    if (!_specifiers) {
        MGLinksEnsureDefaults();
        NSMutableArray *m = [NSMutableArray array];

        PSSpecifier *g = MGNewSpec(self, @"链接预设", nil, NULL, NULL, nil, PSGroupCell);
        [g setProperty:@"链接预设" forKey:@"label"];
        [g setProperty:@"填好名称和网址后, 手势的动作选择页「打开链接」分组里就会出现对应条目。\n支持任意 scheme: shortcuts:// (运行快捷指令)、weixin:// (微信)、https:// 网页等。\n清空名称即删除该条; 手势里已绑定但被删除的链接将自动失效。" forKey:@"footerText"];
        [m addObject:g];

#define MG_LINK_ROWS(I) \
        { \
            PSSpecifier *n = MGNewSpec(self, [NSString stringWithFormat:@"链接%u 名称", I], self, \
                @selector(mgLink##I##NameSet:), @selector(mgLink##I##NameGet:), nil, PSEditTextCell); \
            [m addObject:n]; \
            PSSpecifier *u = MGNewSpec(self, [NSString stringWithFormat:@"链接%u 网址", I], self, \
                @selector(mgLink##I##URLSet:), @selector(mgLink##I##URLGet:), nil, PSEditTextCell); \
            [m addObject:u]; \
        }
        MG_LINK_ROWS(0) MG_LINK_ROWS(1) MG_LINK_ROWS(2) MG_LINK_ROWS(3)
        MG_LINK_ROWS(4) MG_LINK_ROWS(5) MG_LINK_ROWS(6) MG_LINK_ROWS(7)

        _specifiers = [m copy];
    }
    return _specifiers;
}

@end
