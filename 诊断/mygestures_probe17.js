// 列出 SpringBoardServices 全部 Open/URL 相关导出符号
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var m = Process.findModuleByName('SpringBoardServices');
console.log('[模块] ' + (m ? m.path : '未找到'));
if (m) {
    var out = [];
    m.enumerateExports().forEach(function (e) {
        if (/open|Open/i.test(e.name)) out.push(e.name + ' (' + e.type + ')');
    });
    console.log(out.length ? out.join('\n') : '(无 Open 相关导出)');
}
console.log('[done]');
