// 探测11: 1) openURL 到底有没有真实生效 2) openApp 崩溃修复尝试的弹药侦察
// 用法: timeout 18 frida -U -n SpringBoard -l mygestures_api_probe11.js -q < /dev/null

// 1) SBMainWorkspace / FBSSystemService 里所有 URL / open 相关方法 (找 URL 打开的真实链路)
function dumpMethods(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 14);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
dumpMethods('SBMainWorkspace', /URL|penApplication/i, 14);
dumpMethods('FBSSystemService', /open/i, 10);
dumpMethods('UIApplication', /openURL/i, 6);

// 2) 挂钩 SBMainWorkspace 的 URL 处理方法 (若 openURL 真实生效, 钩子会响)
try {
    var mw = ObjC.classes.SBMainWorkspace;
    mw.$ownMethods.forEach(function (m) {
        if (/URL/i.test(m) && m.charAt(0) === '-') {
            try {
                Interceptor.attach(mw[m].implementation, {
                    onEnter: function () { console.log('*** [触发] SBMainWorkspace ' + m + ' ***'); }
                });
            } catch (e) {}
        }
    });
    console.log('[hook] SBMainWorkspace URL 方法挂钩完成');
} catch (e) { console.log('[hook] ERR: ' + e); }

// 3) 实弹: 发 prefs URL, 看钩子是否触发 (判断 openURL 是真开还是哑火)
var CFNCGet = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterGetDarwinNotifyCenter'), 'pointer', []);
var CFNCPost = new NativeFunction(Module.findExportByName(null, 'CFNotificationCenterPostNotification'), 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'int']);
// 直接调用 openURL (与 tweak 相同路径)
try {
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var url = ObjC.classes.NSURL['+ URLWithString:']('prefs:root=General');
    svc.openURL_application_options_clientPort_withResult_(url, NULL, NULL, 0, NULL);
    console.log('>>> 已调用 openURL prefs:root=General');
} catch (e) { console.log('[openURL] ERR: ' + e); }

// 4) 图标 API 侦察
console.log('===== 图标 API =====');
try {
    var copyMethodList = new NativeFunction(Module.findExportByName(null, 'class_copyMethodList'), 'pointer', ['pointer', 'pointer']);
    var methodGetName = new NativeFunction(Module.findExportByName(null, 'method_getName'), 'pointer', ['pointer']);
    var selGetName = new NativeFunction(Module.findExportByName(null, 'sel_getName'), 'pointer', ['pointer']);
    var objectGetClass = new NativeFunction(Module.findExportByName(null, 'object_getClass'), 'pointer', ['pointer']);
    function metaMethods(clsName, re) {
        var cls = new NativeFunction(Module.findExportByName(null, 'objc_getClass'), 'pointer', ['pointer'])(Memory.allocUtf8String(clsName));
        if (cls.isNull()) { console.log('[icon] ' + clsName + ' 不存在'); return; }
        var countPtr = Memory.alloc(4);
        var list = copyMethodList(objectGetClass(cls), countPtr);
        var n = countPtr.readInt(), out = [];
        for (var i = 0; i < n; i++) {
            var m = Memory.readUtf8String(selGetName(methodGetName(list.add(i * Process.pointerSize).readPointer())));
            if (re.test(m)) out.push(m);
        }
        console.log('[icon] ' + clsName + ' 类方法: ' + (out.length ? out.slice(0, 8).join(' | ') : '(无匹配)'));
    }
    metaMethods('UIImage', /conImage|applicationIcon/i);
    var lsap = ObjC.classes.LSApplicationProxy;
    lsap.$ownMethods.forEach(function (m) { if (/icon/i.test(m)) console.log('[icon] LSApplicationProxy: ' + m); });
} catch (e) { console.log('[icon] ERR: ' + e); }

// 5) FBProcessManager 侦察 (clientProcess 修复弹药)
dumpMethods('FBProcessManager', /rocess/i, 12);
Object.keys(ObjC.classes).filter(function (c) { return /ApplicationRequest/i.test(c); }).slice(0, 8)
    .forEach(function (c) { console.log('[类] ' + c); });
console.log('[done]');
