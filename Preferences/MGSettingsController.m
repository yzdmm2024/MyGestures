// 设置面板主控制器（设置 → 我的手势）
// 只 import Preferences 私有框架（坑E：必须显式链接，否则真机报「已损坏或丢失必要的资源」）
#import <Preferences/Preferences.h>

@interface MGSettingsController : PSListController
@end

@implementation MGSettingsController

- (NSArray *)specifiers
{
    if (!_specifiers) {
        // 加载 bundle 里的 Root.plist
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end
