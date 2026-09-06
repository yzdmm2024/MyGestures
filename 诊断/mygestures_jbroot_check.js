// MyGestures 面板诊断: 宿主架构 + jbroot 解析 + dlopen 面板 bundle + 抓设置进程崩溃日志
// 用法: frida -U -n SpringBoard -l mygestures_jbroot_check.js -q < /dev/null

// 1) 宿主架构
var m0 = Process.mainModule;
console.log('[host] ' + m0.name + ' cputype=0x' + Memory.readU32(m0.base.add(4)).toString(16) +
            ' cpusub=0x' + Memory.readU32(m0.base.add(8)).toString(16));

// 2) 解析 jbroot
var jbroot = null;
Process.enumerateModules().forEach(function (m) {
    if (!jbroot) {
        var match = m.path.match(/^.*\.jbroot-[0-9A-Fa-f]+/);
        if (match) jbroot = match[0];
    }
});
try {
    if (!jbroot) {
        var fm = ObjC.classes.NSFileManager.defaultManager();
        var err = Memory.alloc(Process.pointerSize);
        Memory.writePointer(err, ptr(0));
        var items = fm.contentsOfDirectoryAtPath_error_('/private/var/containers/Bundle/Application/', err);
        var n = items.count();
        for (var i = 0; i < n; i++) {
            var name = items.objectAtIndex_(i) + '';
            if (name.indexOf('.jbroot-') === 0) {
                jbroot = '/private/var/containers/Bundle/Application/' + name;
                break;
            }
        }
    }
} catch (e) { console.log('[jbroot] list err: ' + e); }
console.log('[jbroot] ' + jbroot);

if (jbroot) {
    var dlopen_f = new NativeFunction(Module.findExportByName(null, 'dlopen'), 'pointer', ['pointer', 'int']);
    var dlerror_f = new NativeFunction(Module.findExportByName(null, 'dlerror'), 'pointer', []);
    function tryDlopen(p) {
        try {
            var h = dlopen_f(Memory.allocUtf8String(p), 1);
            if (!h.isNull()) return 'OK handle=' + h;
            var ep = dlerror_f();
            return ep.isNull() ? 'FAIL (no msg)' : ('FAIL: ' + Memory.readUtf8String(ep));
        } catch (e) { return 'EXC: ' + e; }
    }
    // 面板 bundle 可执行 (dlopen 会执行初始化, 复现 dyld 报错)
    console.log('[dlopen] MyGesturesPrefs -> ' +
        tryDlopen(jbroot + '/Library/PreferenceBundles/MyGesturesPrefs.bundle/MyGesturesPrefs'));
}

// 3) 设备崩溃日志: 找最新的 Preferences(设置) 崩溃 .ips, 打印头部关键行
try {
    var NSFileManager = ObjC.classes.NSFileManager.defaultManager();
    var err2 = Memory.alloc(Process.pointerSize);
    Memory.writePointer(err2, ptr(0));
    var dir = '/var/mobile/Library/Logs/CrashReporter';
    var files = NSFileManager.contentsOfDirectoryAtPath_error_(dir, err2);
    var crashes = [];
    for (var i = 0; i < files.count(); i++) {
        var f = files.objectAtIndex_(i) + '';
        if (f.indexOf('Preferences-') === 0 && f.endsWith('.ips')) crashes.push(f);
    }
    crashes.sort();
    console.log('[crashlogs] 设置进程崩溃日志共 ' + crashes.length + ' 个');
    if (crashes.length > 0) {
        var latest = crashes[crashes.length - 1];
        console.log('[crashlogs] 最新: ' + latest);
        var NSString = ObjC.classes.NSString;
        var content = NSString.stringWithContentsOfFile_encoding_error_(
            dir + '/' + latest, 4 /*NSUTF8*/, Memory.alloc(Process.pointerSize));
        var s = content ? (content + '') : '(读取失败)';
        // 打印关键行: 崩溃类型/异常/引用的二进制/最后调用栈前若干行
        var lines = s.split('\n');
        var shown = 0;
        for (var j = 0; j < lines.length && shown < 40; j++) {
            var L = lines[j];
            if (j < 60 || /exception|faulting|triggered|MyGestures| MG |Preferences|dyld|Thread [0-9]+ Crashed|Termination/.test(L)) {
                console.log('  | ' + L.substring(0, 200));
                shown++;
            }
        }
    }
} catch (e) { console.log('[crashlogs] err: ' + e); }
console.log('[done]');
