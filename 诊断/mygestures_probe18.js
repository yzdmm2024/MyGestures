// 扫描 SB 已加载的 TweakInject 模块, 找包含「预设链接/打开应用」菜单的那个 tweak
var pat = Memory.allocUtf8String('预设链接');
function memContains(mod, strBytes) {
    try {
        var results = Memory.scanSync(mod.base, mod.size, strBytes);
        return results.length > 0;
    } catch (e) { return false; }
}
// UTF-8 与 UTF-16LE 两种 pattern
function hexOf(utf8) {
    var a = Memory.allocUtf8String(utf8);
    var bytes = [];
    for (var i = 0; i < utf8.length * 3 + 3; i++) {
        var b = a.add(i).readU8();
        if (b === 0) break;
        bytes.push(('0' + b.toString(16)).slice(-2));
    }
    return bytes.join(' ');
}
var pU8 = hexOf('预设链接');
var mods = Process.enumerateModules().filter(function (m) { return m.path.indexOf('TweakInject') >= 0; });
console.log('[*] TweakInject 模块 ' + mods.length + ' 个, 扫描中...');
mods.forEach(function (m) {
    if (memContains(m, pU8)) console.log('*** 命中: ' + m.name + '  ' + m.path);
});
console.log('[done]');
