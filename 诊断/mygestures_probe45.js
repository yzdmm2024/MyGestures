function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 14);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
dump('SBBluetoothController', /nable|oggle|ower/i, 14);
console.log('===== 类名含 LowPower =====');
Object.keys(ObjC.classes).filter(function (c) { return /LowPower/i.test(c); }).slice(0, 8)
    .forEach(function (c) { console.log('  ' + c); });
dump('SBCameraHardwareButton', /^ \+/, 8);
console.log('[done]');
