// 零风险验证: BluetoothManager / WFControlCenterStateMonitor / SBBatteryManager
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager'), 1);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit'), 1);

function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
dump('BluetoothManager', /shared|luetoothState|ower/i, 12);
dump('WFControlCenterStateMonitor', /shared|onitor|erform/i, 12);
dump('WFWiFiStateMonitor', /shared|onitor/i, 10);
dump('SBBatteryManager', /ower/i, 10);
console.log('[done]');
