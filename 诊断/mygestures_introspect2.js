// 查 PSListController 的 specifier 传参属性 + PSSpecifier 值显示相关方法
var copyMethodList = new NativeFunction(Module.findExportByName(null, 'class_copyMethodList'), 'pointer', ['pointer', 'pointer']);
var methodGetName  = new NativeFunction(Module.findExportByName(null, 'method_getName'), 'pointer', ['pointer']);
var selGetName     = new NativeFunction(Module.findExportByName(null, 'sel_getName'), 'pointer', ['pointer']);
var objcGetClass   = new NativeFunction(Module.findExportByName(null, 'objc_getClass'), 'pointer', ['pointer']);

function methodsOf(name) {
    var out = [];
    var cls = objcGetClass(Memory.allocUtf8String(name));
    var countPtr = Memory.alloc(4);
    var list = copyMethodList(cls, countPtr);
    var n = countPtr.readInt();
    for (var i = 0; i < n; i++) {
        var m = list.add(i * Process.pointerSize).readPointer();
        out.push(Memory.readUtf8String(selGetName(methodGetName(m))));
    }
    return out.sort();
}

console.log('===== PSListController 含 specifier/Detail 的实例方法 =====');
methodsOf('PSListController').forEach(function (m) {
    if (/specifer|specifier|Detail|detail/i.test(m)) console.log('  ' + m);
});
console.log('\n===== PSListController 导航相关 =====');
methodsOf('PSListController').forEach(function (m) {
    if (/avigation|opView|ushView/.test(m)) console.log('  ' + m);
});
console.log('\n===== PSSpecifier cell/值显示相关 =====');
methodsOf('PSSpecifier').forEach(function (m) {
    if (/cell|itle|value/i.test(m)) console.log('  ' + m);
});
console.log('[done]');
