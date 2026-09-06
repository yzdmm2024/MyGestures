// 探测8d: 正确的 frida 语法最终验证 openApp + App枚举
try {
    var ws = ObjC.classes.LSApplicationWorkspace.defaultWorkspace();
    var apps = ws.allInstalledApplications();   // 16.6 真名 (不是 allInstalledApps)
    console.log('[枚举] allInstalledApplications count=' + apps.count());
    for (var i = 0; i < Math.min(apps.count(), 3); i++) {
        var a = apps.objectAtIndex_(i);
        console.log('  ' + (a.bundleIdentifier() + '') + ' / ' + (a.localizedName() + ''));
    }
} catch (e) { console.log('[枚举] ERR: ' + e); }

try {
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    req.setTrusted_(true);
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    console.log('[req] ' + req);
    svc.openApplication_options_withResult_(req, NULL, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否弹出设置');
} catch (e) { console.log('[openApp] ERR: ' + e); }
console.log('[done]');
