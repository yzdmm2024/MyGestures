// 找 SB 内部「点图标打开App」的真实入口函数
function dumpAll(clsName, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods;
        console.log('[probe] ' + clsName + ' 共 ' + own.length + ' 方法');
        own.filter(function (m) { return /aunch|ctivate|penApp/i.test(m); }).slice(0, 20)
            .forEach(function (m) { console.log('  ' + m); });
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
dumpAll('SBMainWorkspace', 120);
dumpAll('SBIconController', 60);
dumpAll('SBHomeScreenIconImageViewController', 40);
console.log('[done]');
