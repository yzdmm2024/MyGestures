// 探测8c: 用原始 objc_msgSend 调 openApplication (与 tweak 实现完全一致)
var msgSend = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer','pointer','pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }

var reqCls = ObjC.classes.FBSystemServiceOpenApplicationRequest.$handle
    ? ObjC.classes.FBSystemServiceOpenApplicationRequest.$handle
    : new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String('FBSystemServiceOpenApplicationRequest'));
var svcCls = new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String('FBSSystemService'));
var svc = msgSend(svcCls, SEL('sharedService'), NULL, NULL, NULL);
console.log('[svc] ' + svc);

var a = msgSend(reqCls, SEL('alloc'), NULL, NULL, NULL);
var req = msgSend(a, SEL('initWithBundleId:'), Memory.allocUtf8String('com.apple.Preferences'), NULL, NULL);
console.log('[req] ' + new ObjC.Object(req));
msgSend(req, SEL('setTrusted:'), Memory.allocUtf8String(''), 1, NULL); // BOOL 经 x2 寄存器传 1
console.log('[调用] openApplication:options:withResult: ...');
msgSend(svc, SEL('openApplication:options:withResult:'), req, NULL, NULL);
console.log('[OK] 返回未崩 —— 看手机是否弹出设置页');
