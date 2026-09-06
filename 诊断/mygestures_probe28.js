// 最终一发: BKSSystemService openApplication (backboardd 通道)
try {
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    var mgr = ObjC.classes.FBProcessManager['+ sharedInstance']();
    req.setClientProcess_(mgr.processForPID_(Process.id));
    var svc = ObjC.classes.BKSSystemService['+ sharedService']()
        ? ObjC.classes.BKSSystemService['+ sharedService']()
        : ObjC.classes.BKSSystemService['+ sharedInstance']();
    console.log('[svc] ' + svc);
    svc.openApplication_options_withResult_(req, NULL, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否弹出设置');
} catch (e) { console.log('[BKS] ERR: ' + e); }
console.log('[done]');
