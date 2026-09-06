// 探测12: T1=UIApplication openURL  T2=openApplication+clientProcess(自家进程)
function dumpMethods(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) return;
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 8);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) {}
}
dumpMethods('SBMainWorkspace', /oreground|rontmost/i, 6);

// 前台 App 检查器 (验证效果用)
function foregroundApp() {
    try {
        var ws = ObjC.classes.SBMainWorkspace['+ sharedInstance']();
        var m = ['foregroundApplication', 'frontmostApplication', '_foregroundApplication'].find(function (s) {
            return ws.respondsToSelector(ObjC.selector(s));
        });
        if (m) { var a = ws[m](); return a ? (a.bundleIdentifier ? a.bundleIdentifier() + '' : (a + '')) : '(无前台App)'; }
        return '(无方法)';
    } catch (e) { return 'ERR ' + e; }
}
console.log('[当前前台] ' + foregroundApp());

// T1: UIApplication openURL
try {
    var app = ObjC.classes.UIApplication.sharedApplication();
    var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
    app.openURL_(url);
    console.log('[T1] UIApplication openURL 已调用, 前台: ' + foregroundApp());
} catch (e) { console.log('[T1] ERR: ' + e); }

// T2: openApplication + clientProcess = SpringBoard 自己
try {
    var mgr = ObjC.classes.FBProcessManager['+ sharedInstance']();
    var myProc = mgr.processForPID_(Process.id);
    console.log('[T2] 自家进程: ' + myProc);
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    req.setClientProcess_(myProc);
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var ws = ObjC.classes.SBMainWorkspace['+ sharedInstance']();
    ws.systemService_handleOpenApplicationRequest_withCompletion_(svc, req, NULL);
    console.log('[T2] 调用返回未崩, 前台: ' + foregroundApp());
} catch (e) { console.log('[T2] ERR: ' + e); }
console.log('[done]');
