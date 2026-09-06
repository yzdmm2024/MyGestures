// 试 SBHIconManager 的两个内部启动方法
try {
    var ic = ObjC.classes.SBIconController['+ sharedInstance']();
    var mgr = ic.iconManager();
    var model = ic.model();
    var icon = model.applicationIconForBundleIdentifier_('com.apple.shortcuts');
    console.log('[icon] ' + (icon && !icon.isNull() ? 'OK' : 'NULL'));
    // 路线A: iconModel:launchIcon:fromLocation:context: 全 nil 探路
    mgr.iconModel_launchIcon_fromLocation_context_(model, icon, NULL, NULL);
    console.log('[A-OK] iconModel:launchIcon:... 返回未崩 —— 看手机是否打开快捷指令');
} catch (e) { console.log('[A] ERR: ' + e); }
console.log('[done]');
