// 探测: 各开关在 16.6 的真实方法名
function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 14);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
dump('SBWiFiManager', /ifi/i, 16);
dump('SBTelephonyManager', /irplane|oggle|nable/i, 14);
console.log('===== 类名含 Bluetooth 的 SB 类 =====');
Object.keys(ObjC.classes).filter(function (c) { return /Bluetooth/i.test(c) && c.indexOf('SB') === 0; }).slice(0, 8)
    .forEach(function (c) { console.log('  ' + c); });
dump('SBLowPowerModeManager', /ower/i, 14);
dump('SBCameraHardwareButton', /./i, 16);
console.log('[done]');
