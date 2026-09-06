// 无钩子最小脚本: 测 attach + openApplication 链
var m0 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer']);
var m1 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer']);
var mI = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','int']);
var m3 = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer','pointer','pointer']);
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
m1(req, SEL('setClientProcess:'), proc);
var opts = m0(m0(OBJ('FBSOpenApplicationOptions'), SEL('alloc')), SEL('init'));
console.log('[调用前] req/proc/opts 就绪');
m3(svc, SEL('openApplication:withOptions:completion:'), req, opts, NULL);
console.log('[OK] 返回未崩 —— 看手机是否打开设置');
console.log('[done]');
