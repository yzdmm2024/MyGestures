// 试: SBIconViewMap 拿图标视图 → _launchFromIconView:withActions:
try {
    var vmCls = ObjC.classes.SBIconViewMap;
    if (!vmCls) { console.log('[vm] SBIconViewMap 不存在'); }
    else {
        var vm = vmCls['+ sharedInstance'] ? vmCls['+ sharedInstance']() : NULL;
        console.log('[vm] ' + vm);
        var ic = ObjC.classes.SBIconController['+ sharedInstance']();
        var model = ic.model();
        var icon = model.applicationIconForBundleIdentifier_('com.apple.shortcuts');
        console.log('[icon] ' + (icon && !icon.isNull() ? 'OK' : 'NULL'));
        // SBIconViewMap 上的 iconView 获取方法
        vmCls.$ownMethods.filter(function (m) { return /iewFor|conView/i.test(m); }).slice(0, 10)
            .forEach(function (m) { console.log('  own: ' + m); });
        if (vm && !vm.isNull()) {
            var view = vm.iconViewForIcon_(icon);
            console.log('[view] ' + (view && !view.isNull() ? view.description().substring(0, 60) : 'NULL'));
            if (view && !view.isNull()) {
                var icc = ObjC.classes.SBIconController['+ sharedInstance']();
                icc._launchFromIconView_withActions_(view, NULL);
                console.log('[OK] _launchFromIconView 返回未崩 —— 看手机是否打开快捷指令');
            }
        }
    }
} catch (e) { console.log('[ERR] ' + e); }
console.log('[done]');
