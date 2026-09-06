// 验证: SBSOpenSensitiveURL 是否真实打开 (钩子) + 测 camera:// 
var impl = ObjC.classes.SBMainWorkspace['- _handleOpenApplicationRequest:options:activationSettings:origin:withResult:'].implementation;
Interceptor.attach(impl, {
    onEnter: function (args) { console.log('*** [触发] SB 总入口收到打开请求 ***'); }
});
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var fn = new NativeFunction(Module.findExportByName(null, 'SBSOpenSensitiveURL'), 'void', ['pointer', 'int']);

var u1 = ObjC.classes.NSURL.URLWithString_('prefs:root=General');
fn(u1.handle, 0);
console.log('[已调用] prefs:root=General');

var u2 = ObjC.classes.NSURL.URLWithString_('camera://');
fn(u2.handle, 0);
console.log('[已调用] camera://');
console.log('[done] 若上面出现 *** 触发 *** 行 = 请求真实到达');
