// 实验: 蓝牙与WiFi真实切换 (PinkyPonk 同款通路)
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager'), 1);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit'), 1);

var m0 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer']);
var m1 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
function OBJ(s) { return new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String(s)); }

// 1) 蓝牙
try {
    var bm = m0(OBJ('BluetoothManager'), SEL('sharedInstance'));
    var before = m0(bm, SEL('bluetoothState'));
    m0(bm, SEL('bluetoothStateAction'));
    var after = m0(bm, SEL('bluetoothState'));
    console.log('[蓝牙] 状态 ' + before + ' → ' + after + ' (变化=成功)');
} catch (e) { console.log('[蓝牙] ERR: ' + e); }

// 2) WiFi: 新建 CC 监控实例并执行动作
try {
    var mon = m0(m0(OBJ('WFControlCenterStateMonitor'), SEL('alloc')), SEL('init'));
    console.log('[wifi监控] ' + (mon.isNull() ? 'NULL' : 'OK'));
    m1(mon, SEL('performAction:'), NULL);
    console.log('[wifi] performAction 已调用 —— 看控制中心 WiFi 是否切换');
} catch (e) { console.log('[wifi] ERR: ' + e); }
console.log('[done]');
