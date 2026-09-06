// 重试: activateApplication (带 nil 守卫)
try {
    var appCtl = ObjC.classes.SBApplicationController['+ sharedInstance']();
    var app = appCtl.applicationWithBundleIdentifier_('com.apple.Preferences');
    console.log('[app] ' + (app && !app.isNull() ? app.description().substring(0, 80) : 'NULL'));
    if (app && !app.isNull()) {
        var ui = ObjC.classes.SBUIController['+ sharedInstance']();
        ui.activateApplication_fromIcon_location_activationSettings_actions_(app, NULL, NULL, NULL, NULL);
        console.log('[OK] 返回未崩 —— 看手机是否打开设置');
    }
} catch (e) { console.log('[ERR] ' + e); }
console.log('[done]');
