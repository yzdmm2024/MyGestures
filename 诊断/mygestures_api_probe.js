// iOS 16.6 SpringBoard 可用 API 大探测 + 立即实弹测试
// 用法: timeout 20 frida -U -n SpringBoard -l mygestures_api_probe.js -q < /dev/null

// 1) 找截图相关类
console.log('===== 类名含 Screenshot/ScreenCapture 的已加载类 =====');
Object.keys(ObjC.classes).filter(function (c) { return /Screenshot|ScreenCapture/i.test(c); }).slice(0, 15)
    .forEach(function (c) { console.log('  ' + c); });

// 2) dlsym: SpringBoardServices 里的 C 函数在 SB 进程内是否可用
console.log('===== dlsym 探测 =====');
var d = Module.findExportByName(null, 'SBSLockDevice');
console.log('  SBSLockDevice: ' + (d ? '存在' : '不存在'));
var d2 = Module.findExportByName(null, 'SBSOpenSensitiveURLWithOptions');
console.log('  SBSOpenSensitiveURLWithOptions: ' + (d2 ? '存在' : '不存在'));
var d3 = Module.findExportByName(null, 'MRMediaRemoteSendCommand');
console.log('  MRMediaRemoteSendCommand: ' + (d3 ? '存在' : '不存在'));

// 3) 关键类方法探测
function probe(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR: ' + e); }
}
probe('SBLockScreenManager', /lock/i);
probe('SBMainWorkspace', /openApplication|aunchApplication|activateHome/i);
probe('SBUIController', /imulate|uttonPress|andleHomeButton/i, 14);
probe('SBMediaController', /play|ause/i, 14);

// 4) 安全版 NSLog 捕获 (只打印含 MyGestures 的格式串)
Interceptor.attach(Module.findExportByName(null, 'NSLog'), {
    onEnter: function (args) {
        try {
            if (args[0].isNull()) return;
            var s = new ObjC.Object(args[0]).toString();
            if (s.indexOf('MyGestures') >= 0) console.log('[SB日志] ' + s);
        } catch (e) {}
    }
});

// 5) 立即实弹: 依次发通知 (截屏/播放暂停/主屏幕/设置面板)
var CFNCGet = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterGetDarwinNotifyCenter'), 'pointer', []);
var CFNCPost = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterPostNotification'), 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'int']);
function post(name) {
    CFNCPost(CFNCGet(), Memory.allocUtf8String(name), NULL, NULL, 1);
    console.log('>>> 已发送: ' + name);
}
post('com.local.mygestures.screenshot');
post('com.local.mygestures.playpause');
post('com.local.mygestures.home');
post('com.local.mygestures.settingspanel');
console.log('[done]');
