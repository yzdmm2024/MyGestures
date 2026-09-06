// 探测8b: openApplication 标准语法重试
try {
    var reqCls = ObjC.classes.FBSystemServiceOpenApplicationRequest;
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var req = reqCls.alloc().initWithBundleId_('com.apple.Preferences');
    if (req.respondsToSelector(ObjC.selector('setTrusted:'))) req.setTrusted_(true);
    console.log('[req] ' + req);
    svc.openApplication_options_withResult_(req, NULL, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否弹出设置');
} catch (e) { console.log('[openApp] ERR: ' + e); }
console.log('[done]');
