// 探测: 蜂窝网络开关 / 相机启动 / 图标视图获取
function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
// 1) 蜂窝数据开关
dump('SBTelephonyManager', /ellular|ataEnabled/i, 12);
// 2) 相机相关类
console.log('===== 类名含 Camera (SB开头优先) =====');
Object.keys(ObjC.classes).filter(function (c) { return /Camera/i.test(c) && /^(SB|SS|FB)/.test(c); }).slice(0, 12)
    .forEach(function (c) { console.log('  ' + c); });
// 3) SBHIconManager 的图标视图获取
dump('SBHIconManager', /iewFor|conView|visible/i, 14);
// 4) SBUIController 的 activateApplication 完整签名
dump('SBUIController', /ctivateApplication/i, 4);
// 5) SBApplicationController
dump('SBApplicationController', /shared|pplicationWith/i, 8);
console.log('[done]');
