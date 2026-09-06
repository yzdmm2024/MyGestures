// 完整试链: SBIconController → model → icon → iconManager:launchIcon:...
try {
    var ic = ObjC.classes.SBIconController['+ sharedInstance']();
    console.log('[ic] ' + ic);
    ['model', 'iconModel', 'iconManager'].forEach(function (p) {
        try { console.log('  ' + p + ' = ' + ic[p]()); } catch (e) { console.log('  ' + p + ' ERR'); }
    });
} catch (e) { console.log('[ic] ERR: ' + e); }

try {
    var ic = ObjC.classes.SBIconController['+ sharedInstance']();
    var model = ic.model ? ic.model() : ic.iconModel();
    var icon = model.applicationIconForBundleIdentifier_('com.apple.Preferences');
    console.log('[icon] ' + icon);
    var mgr = ic.iconManager ? ic.iconManager() : NULL;
    console.log('[mgr] ' + mgr);
    // location 传 nil, 动画关, 完成 nil
    ic.iconManager_launchIcon_location_animated_completionHandler_(mgr, icon, NULL, false, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否打开设置');
} catch (e) { console.log('[launch] ERR: ' + e); }
console.log('[done]');
