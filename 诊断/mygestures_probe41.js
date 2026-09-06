// SBSCreateOpenApplicationService: 官方服务入口, 试它能不能真正开 App
var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
dlopen_f(Memory.allocUtf8String('/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices'), 1);
var createFn = new NativeFunction(Module.findExportByName(null, 'SBSCreateOpenApplicationService'), 'pointer', []);
var svc = createFn();
console.log('[svc] ' + svc);
if (!svc.isNull()) {
    var o = new ObjC.Object(svc);
    console.log('[类] ' + o.$className);
    o.$ownMethods.filter(function (m) { return /open/i.test(m); }).slice(0, 8)
        .forEach(function (m) { console.log('  ' + m); });
}
console.log('[done]');
