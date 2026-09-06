// T3b: 修正 dlopen 调用
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
var h = dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
console.log('[T3] dlopen handle: ' + h);
var sym = Module.findExportByName(null, 'SBSOpenSensitiveURLWithOptions');
console.log('[T3] 符号: ' + (sym ? '存在' : '不存在'));
if (sym) {
    var fn = new NativeFunction(sym, 'void', ['pointer', 'int']);
    var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
    fn(url.$handle, 0);
    console.log('[T3] 已调用 —— 手机若弹出设置-通用页即通路成功');
}
console.log('[done]');
