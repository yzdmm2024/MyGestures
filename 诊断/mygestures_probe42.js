// 关键实验: 官方服务 + 请求 + clientProcess → 打开设置
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var createFn = new NativeFunction(Module.findExportByName(null, 'SBSCreateOpenApplicationService'), 'pointer', []);
var svc = createFn();
var msgSend = new NativeFunction(Module.findExportByName(null, 'objc_msgSend'), 'pointer', ['pointer','pointer','pointer','pointer','pointer']);
var selGet = new NativeFunction(Module.findExportByName(null, 'sel_registerName'), 'pointer', ['pointer']);
function SEL(s) { return selGet(Memory.allocUtf8String(s)); }
function OBJ(s) { return new NativeFunction(Module.findExportByName(null,'objc_getClass'),'pointer',['pointer'])(Memory.allocUtf8String(s)); }

var req = msgSend(msgSend(OBJ('FBSystemServiceOpenApplicationRequest'), SEL('alloc'), NULL, NULL, NULL), SEL('initWithBundleId:'), Memory.allocUtf8String('com.apple.Preferences'), NULL, NULL);
var mgr = msgSend(OBJ('FBProcessManager'), SEL('sharedInstance'), NULL, NULL, NULL);
var proc = msgSend(mgr, SEL('processForPID:'), Memory.allocUtf8String(''), Process.id, NULL); // processForPID:(int) — 参数走 x2? 修正见下
console.log('[req] ' + (req.isNull() ? 'NULL' : new ObjC.Object(req).description().substring(0, 90)));
console.log('[done-初探]');
