// 修正: openApp via SBSCreateOpenApplicationService (clientProcess 正确传参)
var impl = ObjC.classes.SBMainWorkspace['- _handleOpenApplicationRequest:options:activationSettings:origin:withResult:'].implementation;
Interceptor.attach(impl, { onEnter: function () { console.log('*** [触发] SB 总入口收到请求 ***'); } });

var msgSendP = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer','pointer','pointer']);
var msgSendInt = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','int']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
function OBJ(s) { return new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String(s)); }

var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var createFn = new NativeFunction(Module.findExportByName(null, 'SBSCreateOpenApplicationService'), 'pointer', []);
var svc = createFn();

var req = msgSendP(msgSendP(OBJ('FBSystemServiceOpenApplicationRequest'), SEL('alloc'), NULL, NULL), SEL('initWithBundleId:'), Memory.allocUtf8String('com.apple.Preferences'), NULL);
var mgr = msgSendP(OBJ('FBProcessManager'), SEL('sharedInstance'), NULL, NULL);
var proc = msgSendInt(mgr, SEL('processForPID:'), Process.id);
console.log('[req] ' + new ObjC.Object(req).description().substring(0, 90));
console.log('[proc] ' + new ObjC.Object(proc).description().substring(0, 80));
msgSendP(req, SEL('setClientProcess:'), proc, NULL);
var opts = msgSendP(msgSendP(OBJ('FBSOpenApplicationOptions'), SEL('alloc'), NULL, NULL), SEL('init'), NULL, NULL);
console.log('[调用] openApplication:withOptions:completion: ...');
msgSendP(svc, SEL('openApplication:withOptions:completion:'), req, opts, NULL);
console.log('[OK] 返回未崩 —— 看手机是否打开设置');
console.log('[done]');
