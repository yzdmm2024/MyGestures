// 计时: 挂钩 SBS 启动/URL 函数, 发一个动作, 量「通知→执行」延迟
var T0 = 0;
Interceptor.attach(Module.findExportByName(null, 'SBSLaunchApplicationWithIdentifier'), {
    onEnter: function (args) {
        var bid = new ObjC.Object(args[0]).toString();
        console.log('*** [执行] SBS启动App: ' + bid + ' (自通知发出 ' + (Date.now() - T0) + 'ms) ***');
    }
});
Interceptor.attach(Module.findExportByName(null, 'SBSOpenSensitiveURL'), {
    onEnter: function (args) {
        var u = new ObjC.Object(args[0]).toString();
        console.log('*** [执行] SBS打开URL: ' + u + ' (自通知发出 ' + (Date.now() - T0) + 'ms) ***');
    }
});
Interceptor.attach(Module.findExportByName(null, 'SBSSetSystemVolumeCategory'), { onEnter: function () {} });

var m0 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
var CFNCGet = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterGetDarwinNotifyCenter'), 'pointer', []);
var CFNCPost = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterPostNotification'), 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'int']);
var prefSet = new NativeFunction(Module.findExportByName(null, 'CFPreferencesSetAppValue'), 'void', ['pointer', 'pointer', 'pointer']);
var prefSync = new NativeFunction(Module.findExportByName(null, 'CFPreferencesAppSynchronize'), 'void', ['pointer']);
var suite = Memory.allocUtf8String('com.local.mygestures');

var action = Memory.allocUtf8String(ActionPayload || 'camera');
prefSet(Memory.allocUtf8String('pendingAction'), action, suite);
prefSync(suite);
console.log('[发] pendingAction=' + ActionPayload + ', 通知 run');
T0 = Date.now();
CFNCPost(CFNCGet(), Memory.allocUtf8String('com.local.mygestures.run'), NULL, NULL, 1);
setTimeout(function () { console.log('[done] 等待 6 秒结束 (若上面无 *** 执行 *** 行 = SB 没收到/没执行)'); }, 6000);
