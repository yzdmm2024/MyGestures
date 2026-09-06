var impl = ObjC.classes.SBMainWorkspace['- _handleOpenApplicationRequest:options:activationSettings:origin:withResult:'].implementation;
Interceptor.attach(impl, { onEnter: function () { console.log('*** [触发] SB 总入口收到请求 ***'); } });

var m0 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer']);                 // 无参
var m1 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer']);        // 1参
var mI = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','int']);            // int参
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
function OBJ(s) { return new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String(s)); }

var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var createFn = new NativeFunction(Module.findExportByName(null, 'SBSCreateOpenApplicationService'), 'pointer', []);
var svc = createFn();

var req = m1(m0(OBJ('FBSystemServiceOpenApplicationRequest'), SEL('alloc')), SEL('initWithBundleId:'), Memory.allocUtf8String('com.apple.Preferences'));
var mgr = m0(OBJ('FBProcessManager'), SEL('sharedInstance'));
var proc = mI(mgr, SEL('processForPID:'), Process.id);
console.log('[req] ' + new ObjC.Object(req).description().substring(0, 90));
console.log('[proc] ' + new ObjC.Object(proc).description().substring(0, 80));
m1(req, SEL('setClientProcess:'), proc);
var opts = m0(m0(OBJ('FBSOpenApplicationOptions'), SEL('alloc')), SEL('init'));
console.log('[调用] openApplication:withOptions:completion: ...');
var m3 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer','pointer','pointer']);
m3(svc, SEL('openApplication:withOptions:completion:'), req, opts, NULL);
console.log('[OK] 返回未崩 —— 看手机是否打开设置');
console.log('[done]');
