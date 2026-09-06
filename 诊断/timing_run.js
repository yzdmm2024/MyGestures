var T0 = 0;
Interceptor.attach(Module.findExportByName(null, 'SBSLaunchApplicationWithIdentifier'), {
    onEnter: function (args) {
        console.log('*** [执行] SBS启动App: ' + new ObjC.Object(args[0]).toString() + ' (自通知 ' + (Date.now() - T0) + 'ms) ***');
    }
});
Interceptor.attach(Module.findExportByName(null, 'SBSOpenSensitiveURL'), {
    onEnter: function (args) {
        console.log('*** [执行] SBS打开URL: ' + new ObjC.Object(args[0]).toString() + ' (自通知 ' + (Date.now() - T0) + 'ms) ***');
    }
});

var m1 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
var CFNCGet = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterGetDarwinNotifyCenter'), 'pointer', []);
var CFNCPost = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterPostNotification'), 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'int']);
var prefSet = new NativeFunction(Module.findExportByName(null, 'CFPreferencesSetAppValue'), 'void', ['pointer', 'pointer', 'pointer']);
var prefSync = new NativeFunction(Module.findExportByName(null, 'CFPreferencesAppSynchronize'), 'void', ['pointer']);
var suite = Memory.allocUtf8String('com.local.mygestures');
var cfCreate = new NativeFunction(Module.findExportByName(null, 'CFStringCreateWithCString'), 'pointer', ['pointer', 'pointer', 'int']);
function CFSTR(s) { return cfCreate(NULL, Memory.allocUtf8String(s), 0x08000100); }

prefSet(Memory.allocUtf8String('pendingAction'), CFSTR('wifi'), suite);
prefSync(suite);
console.log('[发] pendingAction=wifi');
T0 = Date.now();
CFNCPost(CFNCGet(), Memory.allocUtf8String('com.local.mygestures.run'), NULL, NULL, 1);
console.log('[已发] run 通知');
