// 零风险: 扫描关键框架的全部 Open URL 相关 C 导出
var frameworks = ['SpringBoardServices', 'FrontBoardServices', 'BackBoardServices', 'SpringBoardFoundation', 'BaseBoard', 'UIKitCore'];
frameworks.forEach(function (fw) {
    try {
        var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
        dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/' + fw + '.framework/' + fw), 1);
        dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/' + fw + '.framework/' + fw), 1);
    } catch (e) {}
});
var seen = {};
Process.enumerateModules().forEach(function (m) {
    if (!/SpringBoard|FrontBoard|BackBoard|BaseBoard|UIKit/i.test(m.name)) return;
    try {
        m.enumerateExports().forEach(function (e) {
            if (/OpenSensitiveURL|OpenURL|openURL/i.test(e.name) && e.type === 'function' && !seen[e.name]) {
                seen[e.name] = m.name;
            }
        });
    } catch (e) {}
});
Object.keys(seen).forEach(function (k) { console.log('  ' + k + '   [' + seen[k] + ']'); });
console.log('[done]');
