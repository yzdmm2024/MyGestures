// 探测13: T2 openApplication+clientProcess(单独测) → T3 dlopen SpringBoardServices 用老API开URL
try {
    var mgr = ObjC.classes.FBProcessManager['+ sharedInstance']();
    var myProc = mgr.processForPID_(Process.id);
    console.log('[T2] 自家进程: ' + myProc);
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    req.setClientProcess_(myProc);
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var ws = ObjC.classes.SBMainWorkspace['+ sharedInstance']();
    ws.systemService_handleOpenApplicationRequest_withCompletion_(svc, req, NULL);
    console.log('[T2] 调用返回未崩 —— 看手机是否弹出设置');
} catch (e) { console.log('[T2] ERR: ' + e); }

try {
    var h = dlopen('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices', 1);
    console.log('[T3] dlopen SpringBoardServices: ' + h);
    var sym = Module.findExportByName(null, 'SBSOpenSensitiveURLWithOptions');
    console.log('[T3] SBSOpenSensitiveURLWithOptions: ' + (sym ? '存在' : '不存在'));
    if (sym) {
        var fn = new NativeFunction(sym, 'void', ['pointer', 'int']);
        var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
        fn(url.$handle, 0);
        console.log('[T3] 已调用 —— 看手机是否弹出设置');
    }
} catch (e) { console.log('[T3] ERR: ' + e); }
console.log('[done]');
