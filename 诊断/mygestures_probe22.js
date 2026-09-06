// 精简重跑: launchIcon 完整链
try {
    var ic = ObjC.classes.SBIconController['+ sharedInstance']();
    var model = ic.model();
    var icon = model.applicationIconForBundleIdentifier_('com.apple.Preferences');
    var mgr = ic.iconManager();
    console.log('[icon] ' + (icon ? icon.description().substring(0, 60) : 'NULL'));
    console.log('[mgr] ' + (mgr ? 'OK' : 'NULL'));
    ic.iconManager_launchIcon_location_animated_completionHandler_(mgr, icon, NULL, false, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否打开设置');
} catch (e) { console.log('[launch] ERR: ' + e); }
console.log('[done]');
