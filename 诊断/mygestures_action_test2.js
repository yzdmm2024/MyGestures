// 动作链诊断 v2: 挂钩各动作的最终私有方法 + 发通知, 判断断点在哪一环
// 用法: timeout 25 frida -U -n SpringBoard -l mygestures_action_test2.js -q < /dev/null

function tryHook(clsName, selName, tag) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[hook] ' + clsName + ' 类不存在'); return; }
        var m = cls['- ' + selName];
        if (!m) { console.log('[hook] ' + clsName + ' 无方法 ' + selName); return; }
        Interceptor.attach(m.implementation, {
            onEnter: function () { console.log('*** [触发] ' + tag + ' 被调用 ***'); }
        });
        console.log('[hook] OK: ' + clsName + ' -' + selName);
    } catch (e) { console.log('[hook] ERR ' + tag + ': ' + e); }
}

tryHook('SBScreenShotter', 'saveScreenshot', '截屏(saveScreenshot)');
tryHook('SBScreenShotter', 'saveScreenshot:', '截屏(saveScreenshot:)');
tryHook('SBUIController', 'simulateHomeButtonClick', '返回主屏幕');
tryHook('SBMediaController', 'togglePlayPause', '播放/暂停');
tryHook('SBUIController', 'lock', '锁屏');

// SBUIController/SBMediaController 的实际可用方法名探测 (前 25 个含 play/home/lock/screenshot 的)
function probe(clsName, re) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配方法)'));
    } catch (e) { console.log('[probe] ERR: ' + e); }
}
probe('SBUIController', /home|lock/i);
probe('SBMediaController', /play|track|skip/i);
probe('SBScreenShotter', /screenshot/i);
probe('SBWiFiManager', /wifi/i);

// 发通知
var CFNCGet = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterGetDarwinNotifyCenter'), 'pointer', []);
var CFNCPost = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterPostNotification'), 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'int']);
function post(name) {
    CFNCPost(CFNCGet(), Memory.allocUtf8String(name), NULL, NULL, 1);
    console.log('>>> 已发送通知: ' + name);
}
setTimeout(function () { post('com.local.mygestures.flashlight'); }, 2000);
setTimeout(function () { post('com.local.mygestures.screenshot'); }, 5000);
setTimeout(function () { post('com.local.mygestures.playpause'); }, 8000);
setTimeout(function () { post('com.local.mygestures.home'); }, 11000);
setTimeout(function () { console.log('[done] 看上面有没有 *** [触发] 行'); }, 14000);
