// 探测第三轮: OpenApplication 相关类 / 截屏手势管理器单例 / 媒体切歌方法
// 用法: timeout 12 frida -U -n SpringBoard -l mygestures_api_probe3.js -q < /dev/null

console.log('===== 类名含 OpenApplication / FBApplicationRequest =====');
Object.keys(ObjC.classes).filter(function (c) { return /OpenApplication|FBApplicationRequest/i.test(c); }).slice(0, 10)
    .forEach(function (c) { console.log('  ' + c); });

function probe(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}

probe('SBInteractiveScreenshotGestureManager', /^ [+]/i, 12);           // 类方法(找单例)
probe('SBMediaController', /kip|rack|rev/i, 14);                        // 切歌
probe('SBUIController', /ettings|RL/i, 10);                             // 打开设置

var d = Module.findExportByName(null, 'SBSLockDevice');
console.log('[dlsym] SBSLockDevice=' + (d ? 'OK' : '无'));
console.log('[done]');
