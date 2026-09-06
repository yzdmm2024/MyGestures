try {
    var ic = ObjC.classes.SBIconController['+ sharedInstance']();
    var mgr = ic.iconManager();
    console.log('[mgr类名] ' + mgr.$className);
    // mgr 上的 launch 相关
    mgr.$ownMethods.filter(function (m) { return /aunch/i.test(m); }).slice(0, 12)
        .forEach(function (m) { console.log('  mgr: ' + m); });
} catch (e) { console.log('[mgr] ERR: ' + e); }
console.log('===== 类名含 IconLocation / LocationInfo =====');
Object.keys(ObjC.classes).filter(function (c) { return /IconLocation|LocationInfo/i.test(c); }).slice(0, 8)
    .forEach(function (c) { console.log('  ' + c); });
console.log('===== 类名含 IconViewMap / IconView =====');
Object.keys(ObjC.classes).filter(function (c) { return /IconViewMap|IconListView/i.test(c); }).slice(0, 10)
    .forEach(function (c) { console.log('  ' + c); });
console.log('[done]');
