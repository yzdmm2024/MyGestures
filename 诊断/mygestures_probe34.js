// 实弹: SBUIController activateApplication 打开相机
try {
    var appCtl = ObjC.classes.SBApplicationController['+ sharedInstance']();
    var app = appCtl.applicationWithBundleIdentifier_('com.apple.camera');
    console.log('[app] ' + (app ? app.description().substring(0, 80) : 'NULL'));
    var ui = ObjC.classes.SBUIController['+ sharedInstance']();
    ui.activateApplication_fromIcon_location_activationSettings_actions_(app, NULL, NULL, NULL, NULL);
    console.log('[OK] 调用返回未崩 —— 看手机是否打开相机');
} catch (e) { console.log('[ERR] ' + e); }
console.log('[done]');
