// 网上资料验证: SBSLaunchApplicationWithIdentifier 系列 (按 bundle id 打开 App 的配套 API)
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
['SBSLaunchApplicationWithIdentifier',
 'SBSLaunchApplicationWithIdentifierAndLaunchOptions',
 'SBSLaunchApplicationWithIdentifierAndLaunchOptionsAndOrigin'].forEach(function (name) {
    var sym = Module.findExportByName(null, name);
    console.log('[符号] ' + name + ': ' + (sym ? '存在' : '不存在'));
});
// 顺便查 SpringBoard 主二进制里有没有 (有的函数在主二进制)
var sb = Process.findModuleByName('SpringBoard');
if (sb) {
    ['SBSLaunchApplicationWithIdentifier', 'SBSOpenSensitiveURL'].forEach(function (name) {
        console.log('[SpringBoard二进制] ' + name + ': ' + (sb.findExportByName ? (sb.findExportByName(name) ? '存在' : '不存在') : '?'));
    });
}
console.log('[done]');
