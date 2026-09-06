// 检查 WiFi 当前开关状态
var m0 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
var wm = m0(new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String('SBWiFiManager')), SEL('defaultWorkspace'));
console.log('[WiFi] wiFiEnabled = ' + m0(wm, SEL('wiFiEnabled')));
console.log('[done]');
