// 段: 挂 SB 总入口 _handleOpenApplicationRequest, 再调 openURL, 看是否触发
try {
    var mw = ObjC.classes.SBMainWorkspace['+ sharedInstance']();
    var m = mw.$ownMethods; // 无用, 占位
    var impl = ObjC.classes.SBMainWorkspace['- _handleOpenApplicationRequest:options:activationSettings:origin:withResult:'].implementation;
    Interceptor.attach(impl, {
        onEnter: function (args) {
            console.log('*** [触发] _handleOpenApplicationRequest ***');
            try { console.log('    request: ' + new ObjC.Object(args[2])); } catch (e) {}
        }
    });
    console.log('[hook] 总入口已挂');
} catch (e) { console.log('[hook] ERR: ' + e); }
try {
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var url = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
    svc.openURL_application_options_clientPort_withResult_(url, NULL, NULL, 0, NULL);
    console.log('[已调用] openURL');
} catch (e) { console.log('[openURL] ERR: ' + e); }
console.log('[done] 若上方无 *** 触发 *** 行, 则 openURL 请求没有到达 SpringBoard');
