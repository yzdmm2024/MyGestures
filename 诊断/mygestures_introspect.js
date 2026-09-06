// 反射查询 v2: 用 ObjC C API 枚举方法列表 (frida $ownClassMethods 不可用)
// 用法: frida -U -n SpringBoard -l mygestures_introspect.js -q < /dev/null

var copyMethodList = new NativeFunction(Module.findExportByName(null, 'class_copyMethodList'), 'pointer', ['pointer', 'pointer']);
var methodGetName  = new NativeFunction(Module.findExportByName(null, 'method_getName'), 'pointer', ['pointer']);
var selGetName     = new NativeFunction(Module.findExportByName(null, 'sel_getName'), 'pointer', ['pointer']);
var objectGetClass = new NativeFunction(Module.findExportByName(null, 'object_getClass'), 'pointer', ['pointer']);
var objcGetClass   = new NativeFunction(Module.findExportByName(null, 'objc_getClass'), 'pointer', ['pointer']);

function methodsOf(clsPtr, meta) {
    var out = [];
    try {
        var countPtr = Memory.alloc(4);
        var list = copyMethodList(meta ? objectGetClass(clsPtr) : clsPtr, countPtr);
        var n = countPtr.readInt();
        for (var i = 0; i < n; i++) {
            var m = list.add(i * Process.pointerSize).readPointer();
            var sel = methodGetName(m);
            out.push(Memory.readUtf8String(selGetName(sel)));
        }
    } catch (e) { out.push('ERR: ' + e); }
    return out;
}
function dump(name, meta, filter) {
    var cls = objcGetClass(Memory.allocUtf8String(name));
    if (cls.isNull()) { console.log('[!] ' + name + ' 不存在'); return; }
    console.log('\n===== ' + name + ' ' + (meta ? '类方法' : '实例方法') + ' =====');
    var arr = methodsOf(cls, meta);
    arr.sort();
    for (var i = 0; i < arr.length; i++) {
        if (!filter || filter.test(arr[i])) console.log('  ' + arr[i]);
    }
}

// 先 dlopen 面板 bundle, 注册我们的 category
var jbroot = null;
Process.enumerateModules().forEach(function (m) {
    if (!jbroot) { var match = m.path.match(/^.*\.jbroot-[0-9A-Fa-f]+/); if (match) jbroot = match[0]; }
});
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
var h = dlopen_f(Memory.allocUtf8String(jbroot + '/Library/PreferenceBundles/MyGesturesPrefs.bundle/MyGesturesPrefs'), 1);
console.log('[dlopen] handle=' + h);

dump('PSSpecifier', true,  /pecifier|roup/i);                       // 类方法: 构造器
dump('PSSpecifier', false, /roperty|setValue/i);                     // 实例: 属性读写
dump('PSListController', false, /pecifierNamed|readPreference|setPreference|table$|reloadSpecifiers|loadSpecifiers/i);
console.log('\n[done]');
