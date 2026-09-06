// 原始 msgSend: activateApplication 打开设置
var msgSend = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'),
    'pointer', ['pointer', 'pointer', 'pointer', 'pointer', 'pointer', 'pointer', 'pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
function OBJ(s) { return new NativeFunction(Module.findExportByName(null, 'objc_getClass'), 'pointer', ['pointer'])(Memory.allocUtf8String(s)); }

var appCtl = msgSend(OBJ('SBApplicationController'), SEL('sharedInstance'), NULL, NULL, NULL, NULL, NULL);
var app = msgSend(appCtl, SEL('applicationWithBundleIdentifier:'), Memory.allocUtf8String('com.apple.Preferences'), NULL, NULL, NULL, NULL);
console.log('[app] ' + (app.isNull() ? 'NULL' : new ObjC.Object(app).description().substring(0, 70)));
if (!app.isNull()) {
    var ui = msgSend(OBJ('SBUIController'), SEL('sharedInstance'), NULL, NULL, NULL, NULL, NULL);
    msgSend(ui, SEL('activateApplication:fromIcon:location:activationSettings:actions:'), app, NULL, NULL, NULL, NULL);
    console.log('[OK] 返回未崩 —— 看手机是否打开设置');
}
console.log('[done]');
