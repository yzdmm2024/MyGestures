// 探测10: trusted=NO (默认) 重测 openApp —— 不调用 setTrusted:
try {
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    // 注意: 不设置 trusted!
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var ws = ObjC.classes.SBMainWorkspace['+ sharedInstance']();
    console.log('[req] ' + req);
    ws.systemService_handleOpenApplicationRequest_withCompletion_(svc, req, NULL);
    console.log('[OK] 返回未崩 —— 看手机是否弹出设置');
} catch (e) { console.log('[openApp] ERR: ' + e); }
console.log('[done]');
