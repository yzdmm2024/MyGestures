// 实弹: 新名字 SBSOpenSensitiveURL 打开 prefs:root=General
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var sym = Module.findExportByName(null, 'SBSOpenSensitiveURL');
console.log('[符号] SBSOpenSensitiveURL: ' + sym);
if (sym) {
    var fn = new NativeFunction(sym, 'void', ['pointer', 'int']);
    var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
    fn(url.$handle, 0);
    console.log('[OK] 已调用 —— 手机应弹出设置-通用页');
}
console.log('[done]');
