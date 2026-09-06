var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/WiFiKit.framework/WiFiKit'), 1);
function dumpAll(clsName, isMeta) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var copyMethodList = new NativeFunction(Module.findExportByName(null, 'class_copyMethodList'), 'pointer', ['pointer', 'pointer']);
        var methodGetName = new NativeFunction(Module.findExportByName(null, 'method_getName'), 'pointer', ['pointer']);
        var selGetName = new NativeFunction(Module.findExportByName(null, 'sel_getName'), 'pointer', ['pointer']);
        var objectGetClass = new NativeFunction(Module.findExportByName(null, 'object_getClass'), 'pointer', ['pointer']);
        var countPtr = Memory.alloc(4);
        var list = copyMethodList(isMeta ? objectGetClass(cls) : cls, countPtr);
        var n = countPtr.readInt(), out = [];
        for (var i = 0; i < n; i++) out.push(Memory.readUtf8String(selGetName(methodGetName(list.add(i * Process.pointerSize).readPointer()))));
        console.log('[probe] ' + clsName + (isMeta ? ' 类方法' : '') + ': ' + (out.length ? out.slice(0, 14).join(' | ') : '(无)'));
    } catch (e) { console.log('[probe] ERR: ' + e); }
}
dumpAll('WFMobileWiFiStateMonitor', true);
dumpAll('WFWiFiStateMonitor', true);
dumpAll('WFControlCenterStateMonitor', true);
dumpAll('PSLowPowerModeSettingsDetail', false);
console.log('[done]');
