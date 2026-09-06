// SpringBoard 动作链实弹诊断:
// 1) 检查 MyGestures.dylib 是否注入 SB
// 2) 挂钩 NSLog 抓取 [MyGestures] 日志
// 3) 主动发送 darwin 通知 (screenshot / playpause / home), 观察哪段日志出现
// 用法: frida -U -n SpringBoard -l mygestures_action_test.js -q   (保持 10 秒)

var mg = Process.enumerateModules().filter(function (m) { return m.name.indexOf('MyGestures') >= 0; });
console.log('[module] ' + (mg.length ? mg[0].path : '!!! MyGestures.dylib 未注入 SpringBoard !!!'));
console.log('[class]  MGTracker: ' + (ObjC.classes.MGTracker ? '存在' : '不存在'));

// 挂 NSLog, 只输出包含 MyGestures 的行 (x0 = format 字符串)
Interceptor.attach(Module.findExportByName(null, 'NSLog'), {
    onEnter: function (args) {
        try {
            var fmt = new ObjC.Object(args[0]).toString();
            if (fmt.indexOf('MyGestures') >= 0) console.log('[SB日志] ' + fmt);
        } catch (e) {}
    }
});

// 发 darwin 通知
var CFNCGet = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterGetDarwinNotifyCenter'), 'pointer', []);
var CFNCPost = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterPostNotification'), 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'int']);
function post(name) {
    var s = Memory.allocUtf8String(name);
    CFNCPost(CFNCGet(), s, NULL, NULL, 1);
    console.log('[发送] ' + name);
}

setTimeout(function () { post('com.local.mygestures.screenshot'); }, 1000);
setTimeout(function () { post('com.local.mygestures.playpause'); }, 3000);
setTimeout(function () { post('com.local.mygestures.home'); }, 5000);
setTimeout(function () {
    console.log('[done] 若上面没有任何 [SB日志], 说明通知没被收到或回调没执行');
}, 7000);
