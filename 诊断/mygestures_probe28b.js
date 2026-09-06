// BKS: alloc/init 实例 + 两种方法变体
try {
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    var mgr = ObjC.classes.FBProcessManager['+ sharedInstance']();
    req.setClientProcess_(mgr.processForPID_(Process.id));
    var svc = ObjC.classes.BKSSystemService.alloc().init();
    console.log('[svc] ' + svc);
    try {
        svc.openApplication_options_withResult_(req, NULL, NULL);
        console.log('[OK-A] 未崩 —— 看手机');
    } catch (e) { console.log('[A] ERR: ' + e); }
} catch (e) { console.log('[BKS] ERR: ' + e); }
console.log('[done]');
