// 读 SpringBoard 崩溃日志的异常原因与崩溃栈
var dir = '/var/mobile/Library/Logs/CrashReporter';
var fm = ObjC.classes.NSFileManager.defaultManager();
var err = Memory.alloc(Process.pointerSize);
Memory.writePointer(err, ptr(0));
var files = fm.contentsOfDirectoryAtPath_error_(dir, err);
var crashes = [];
for (var i = 0; i < files.count(); i++) {
    var f = files.objectAtIndex_(i) + '';
    if (f.indexOf('SpringBoard-') === 0 && f.endsWith('.ips')) crashes.push(f);
}
crashes.sort();
console.log('[*] SpringBoard 崩溃日志 ' + crashes.length + ' 个, 分析最新 1 个');
if (!crashes.length) { console.log('[done]'); } else {
    var s = ObjC.classes.NSString.stringWithContentsOfFile_encoding_error_(dir + '/' + crashes[crashes.length-1], 4, Memory.alloc(Process.pointerSize)) + '';
    var body = s.substring(s.indexOf('\n{'));
    try {
        var j = JSON.parse(body);
        console.log('captureTime: ' + j.captureTime);
        if (j.asi) console.log('ASI: ' + JSON.stringify(j.asi).substring(0, 500));
        if (j.exception) console.log('exception: ' + JSON.stringify(j.exception).substring(0, 300));
        if (j.termination) console.log('termination: ' + JSON.stringify(j.termination).substring(0, 200));
        var imgs = j.usedImages || [];
        function sym(fr) { var img = imgs[fr.imageIndex]; return (img ? (img.name || '') : '?') + ' ' + (fr.symbol || ('+' + fr.imageOffset)); }
        if (j.lastExceptionBacktrace) {
            console.log('--- 异常栈 ---');
            j.lastExceptionBacktrace.slice(0, 14).forEach(function (fr, k) { console.log('  #' + k + ' ' + sym(fr)); });
        }
        if (j.faultingThread !== undefined && j.threads && j.threads[j.faultingThread] && j.threads[j.faultingThread].frames) {
            console.log('--- 崩溃线程栈 ---');
            j.threads[j.faultingThread].frames.slice(0, 14).forEach(function (fr, k) { console.log('  #' + k + ' ' + sym(fr)); });
        }
    } catch (e) { console.log('解析失败: ' + e); }
    console.log('[done]');
}
