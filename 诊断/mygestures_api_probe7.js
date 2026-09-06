// 探测7: LSApplicationWorkspace 的类方法与实例方法真名
// 用法: timeout 12 frida -U -n SpringBoard -l mygestures_api_probe7.js -q < /dev/null
var copyMethodList = new NativeFunction(Module.findExportByName(null, 'class_copyMethodList'), 'pointer', ['pointer', 'pointer']);
var methodGetName = new NativeFunction(Module.findExportByName(null, 'method_getName'), 'pointer', ['pointer']);
var selGetName = new NativeFunction(Module.findExportByName(null, 'sel_getName'), 'pointer', ['pointer']);
var objectGetClass = new NativeFunction(Module.findExportByName(null, 'object_getClass'), 'pointer', ['pointer']);
var objcGetClass = new NativeFunction(Module.findExportByName(null, 'objc_getClass'), 'pointer', ['pointer']);
function methodsOf(name, meta) {
    var out = [];
    var cls = objcGetClass(Memory.allocUtf8String(name));
    if (cls.isNull()) { console.log('[probe] ' + name + ' 不存在'); return out; }
    var countPtr = Memory.alloc(4);
    var list = copyMethodList(meta ? objectGetClass(cls) : cls, countPtr);
    var n = countPtr.readInt();
    for (var i = 0; i < n; i++) out.push(Memory.readUtf8String(selGetName(methodGetName(list.add(i * Process.pointerSize).readPointer()))));
    return out.sort();
}
console.log('===== LSApplicationWorkspace 类方法 =====');
methodsOf('LSApplicationWorkspace', true).forEach(function (m) { console.log('  ' + m); });
console.log('===== LSApplicationWorkspace 实例方法 (apps相关) =====');
methodsOf('LSApplicationWorkspace', false).filter(function (m) { return /pps|nstalled/i.test(m); }).slice(0, 15)
    .forEach(function (m) { console.log('  ' + m); });
console.log('[done]');
