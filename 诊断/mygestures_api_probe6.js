// 探测6: 正确语法重测 App 枚举 + 实弹测试 FBSSystemService openURL (prefs 页面)
// 用法: timeout 15 frida -U -n SpringBoard -l mygestures_api_probe6.js -q < /dev/null

// 1) App 枚举 (类方法正确调用姿势)
try {
    var ws = ObjC.classes.LSApplicationWorkspace['+ defaultWorkspace']();
    var apps = ws['- allInstalledApps']();
    console.log('[枚举] count=' + apps.count());
    for (var i = 0; i < Math.min(apps.count(), 4); i++) {
        var a = apps.objectAtIndex_(i);
        var bid = a.bundleIdentifier ? (a.bundleIdentifier() + '') : '?';
        var nm = a.localizedName ? (a.localizedName() + '') : 'noname';
        console.log('  ' + bid + ' / ' + nm);
    }
} catch (e) { console.log('[枚举] ERR: ' + e); }

// 2) openURL 实弹: 打开 prefs:root=General (若成功, 手机会弹出设置-通用页)
try {
    var svc = ObjC.classes.FBSSystemService['+ sharedService']
        ? ObjC.classes.FBSSystemService['+ sharedService']()
        : ObjC.classes.FBSSystemService['+ sharedApplication']();
    console.log('[svc] ' + svc);
    var url = ObjC.classes.NSURL['+ URLWithString:']('prefs:root=General');
    console.log('[url] ' + url);
    svc['- openURL:application:options:clientPort:withResult:'](url, NULL, NULL, 0, NULL);
    console.log('[已调用] openURL prefs:root=General —— 若手机弹出设置页则通路成功');
} catch (e) { console.log('[openURL] ERR: ' + e); }
console.log('[done]');
