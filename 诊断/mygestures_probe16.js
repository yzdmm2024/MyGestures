// T3: dlopen SpringBoardServices, 用经典 SBSOpenSensitiveURLWithOptions 开 prefs URL
try {
    var h = dlopen('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices', 1);
    console.log('[T3] dlopen handle: ' + h);
    var sym = Module.findExportByName(null, 'SBSOpenSensitiveURLWithOptions');
    console.log('[T3] 符号: ' + (sym ? '存在' : '不存在'));
    if (sym) {
        var fn = new NativeFunction(sym, 'void', ['pointer', 'int']);
        var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
        fn(url.$handle, 0);
        console.log('[T3] 已调用 —— 手机若弹出设置-通用页即通路成功');
    }
} catch (e) { console.log('[T3] ERR: ' + e); }
console.log('[done]');
