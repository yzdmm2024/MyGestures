// 段1: 基线 + 调用 openURL
function prefCount() {
    try {
        var mgr = ObjC.classes.FBProcessManager['+ sharedInstance']();
        var arr = mgr.processesForBundleIdentifier_('com.apple.Preferences');
        return arr ? arr.count() : -1;
    } catch (e) { return 'ERR ' + e; }
}
console.log('[基线] 设置进程数: ' + prefCount());
try {
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
    svc.openURL_application_options_clientPort_withResult_(url, NULL, NULL, 0, NULL);
    console.log('[已调用] openURL prefs:root=General');
} catch (e) { console.log('[openURL] ERR: ' + e); }
