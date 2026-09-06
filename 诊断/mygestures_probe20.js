// 凑齐 launchIcon 链路: SBIconModel 拿图标, SBIconManager 单例, SBIconLocationInfo
function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
dump('SBIconModel', /shared|undleIdentifier|pplicationIcon|expectedIcon/i, 14);
dump('SBIconManager', /shared|efault/i, 10);
dump('SBIconLocationInfo', /init|ith/i, 8);
dump('SBIconController', /shared|efault|ingleton/i, 8);

// 试拿微信/设置的图标对象
try {
    var model = ObjC.classes.SBIconModel['+ sharedInstance']
        ? ObjC.classes.SBIconModel['+ sharedInstance']()
        : ObjC.classes.SBIconModel['+ defaultModel']();
    console.log('[model] ' + model);
    var icon = model.applicationIconForBundleIdentifier_('com.apple.Preferences');
    console.log('[icon] ' + icon);
} catch (e) { console.log('[icon] ERR: ' + e); }
console.log('[done]');
