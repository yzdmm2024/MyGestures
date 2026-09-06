// 用主屏上确定存在的图标试启动链
try {
    var ic = ObjC.classes.SBIconController['+ sharedInstance']();
    var model = ic.model();
    var icon = model.applicationIconForBundleIdentifier_('com.apple.shortcuts');
    console.log('[icon] ' + (icon ? ('OK ' + icon.description().substring(0, 50)) : 'NULL'));
    if (icon) {
        var mgr = ic.iconManager();
        ic.iconManager_launchIcon_location_animated_completionHandler_(mgr, icon, NULL, false, NULL);
        console.log('[OK] 调用返回未崩 —— 看手机是否打开了快捷指令');
    }
} catch (e) { console.log('[launch] ERR: ' + e); }
console.log('[done]');
