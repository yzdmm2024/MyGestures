// 最终验证: 原始 msgSend 走 launchIcon 链 (与 tweak 实现完全一致)
var msgSend = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'),
    'pointer', ['pointer', 'pointer', 'pointer', 'pointer', 'pointer', 'int', 'pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
function OBJ(s) { return new NativeFunction(Module.findExportByName(null, 'objc_getClass'), 'pointer', ['pointer'])(Memory.allocUtf8String(s)); }

var ic = msgSend(OBJ('SBIconController'), SEL('sharedInstance'), NULL, NULL, NULL, 0, NULL);
var model = msgSend(ic, SEL('model'), NULL, NULL, NULL, 0, NULL);
var icon = msgSend(model, SEL('applicationIconForBundleIdentifier:'), Memory.allocUtf8String('com.apple.shortcuts'), NULL, NULL, 0, NULL);
console.log('[icon] ' + (icon.isNull() ? 'NULL' : new ObjC.Object(icon).description().substring(0, 50)));
if (!icon.isNull()) {
    var mgr = msgSend(ic, SEL('iconManager'), NULL, NULL, NULL, 0, NULL);
    console.log('[mgr] ' + (mgr.isNull() ? 'NULL' : 'OK'));
    msgSend(ic, SEL('iconManager:launchIcon:location:animated:completionHandler:'), mgr, icon, NULL, 0, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否打开快捷指令');
}
console.log('[done]');
