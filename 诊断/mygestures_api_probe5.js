// 探测: 1) App枚举 2) FBSSystemService openURL (安全开URL通路) 3) 音量/亮度类
// 用法: timeout 15 frida -U -n SpringBoard -l mygestures_api_probe5.js -q < /dev/null

// 1) App 枚举 (与面板同款代码路径)
try {
    var ws = ObjC.classes.LSApplicationWorkspace.defaultWorkspace();
    var apps = ws.allInstalledApps();
    console.log('[枚举] allInstalledApps count=' + apps.count());
    for (var i = 0; i < Math.min(apps.count(), 4); i++) {
        var a = apps.objectAtIndex_(i);
        var bid = a.bundleIdentifier ? a.bundleIdentifier() + '' : '?';
        var nm = a.localizedName ? (a.localizedName() + '') : 'noname';
        console.log('  ' + bid + ' / ' + nm);
    }
} catch (e) { console.log('[枚举] ERR: ' + e); }

// 2) FBSSystemService 的 openURL 方法 (SB 内打开 URL 的安全通路)
console.log('[FBSSystemService] ' + (ObjC.classes.FBSSystemService ? '存在' : '无'));
try {
    if (ObjC.classes.FBSSystemService) {
        ObjC.classes.FBSSystemService.$ownMethods.forEach(function (m) {
            if (/openURL|penApplication/i.test(m)) console.log('  ' + m);
        });
        console.log('  类方法: ' + ObjC.classes.FBSSystemService.$ownClassMethods.join(' | '));
    }
} catch (e) { console.log('[FBSSystemService] ERR: ' + e); }

// 3) 亮度 / 音量
function probe(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 10);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
probe('SBBacklightController', /rightness/i, 10);
probe('AVSystemController', /olume/i, 8);
console.log('[done]');
