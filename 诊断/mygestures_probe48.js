// 重试: 用 CFStringCreateWithCString 构造参数
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var fn = new NativeFunction(Module.findExportByName(null, 'SBSLaunchApplicationWithIdentifier'), 'void', ['pointer', 'int']);
var cfCreate = new NativeFunction(Module.findExportByName(null, 'CFStringCreateWithCString'), 'pointer', ['pointer', 'pointer', 'int']);
var cf = cfCreate(NULL, Memory.allocUtf8String('com.apple.Preferences'), 0x08000100);
console.log('[cf] ' + cf);
console.log('[调用] SBSLaunchApplicationWithIdentifier(com.apple.Preferences) ...');
fn(cf, 0);
console.log('[OK] 返回未崩 —— 看手机是否打开设置');
console.log('[done]');
