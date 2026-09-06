// 实弹: SBSLaunchApplicationWithIdentifier 打开设置
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var sym = Module.findExportByName(null, 'SBSLaunchApplicationWithIdentifier');
console.log('[符号] ' + sym);
var fn = new NativeFunction(sym, 'void', ['pointer', 'int']);
var bid = ObjC.classes.NSString.stringWithUTF8String_('com.apple.Preferences');
console.log('[调用] SBSLaunchApplicationWithIdentifier(com.apple.Preferences, suspended=0) ...');
fn(bid.handle, 0);
console.log('[OK] 返回未崩 —— 看手机是否打开设置');
console.log('[done]');
