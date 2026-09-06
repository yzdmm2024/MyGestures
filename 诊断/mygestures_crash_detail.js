// 深挖设置进程崩溃原因: 打印 asi(异常原因) / exceptionReason / 崩溃线程栈 / MyGestures 相关帧
var dir = '/var/mobile/Library/Logs/CrashReporter';
var fm = ObjC.classes.NSFileManager.defaultManager();
var err = Memory.alloc(Process.pointerSize);
Memory.writePointer(err, ptr(0));
var files = fm.contentsOfDirectoryAtPath_error_(dir, err);
var crashes = [];
for (var i = 0; i < files.count(); i++) {
    var f = files.objectAtIndex_(i) + '';
    if (f.indexOf('Preferences-') === 0 && f.endsWith('.ips')) crashes.push(f);
}
crashes.sort();
console.log('[*] 崩溃日志: ' + crashes.length + ' 个, 分析最新 3 个');
var targets = crashes.slice(-3);
for (var t = 0; t < targets.length; t++) {
    var path = dir + '/' + targets[t];
    var NSString = ObjC.classes.NSString;
    var content = NSString.stringWithContentsOfFile_encoding_error_(path, 4, Memory.alloc(Process.pointerSize));
    var s = content + '';
    console.log('\n===== ' + targets[t] + ' =====');
    // 第一行是元数据 JSON, 剩下是主体 JSON
    var bodyStart = s.indexOf('\n{');
    var body = s.substring(bodyStart);
    try {
        var j = JSON.parse(body);
        console.log('captureTime: ' + j.captureTime);
        if (j.asi) console.log('ASI: ' + JSON.stringify(j.asi).substring(0, 800));
        if (j.exception && j.exception.type) console.log('exception: ' + j.exception.type + ' ' + (j.exception.signal||'') + (j.exception.codes? ' codes='+j.exception.codes:''));
        if (j.termination) console.log('termination: ' + JSON.stringify(j.termination));
        if (j.faultingThread !== undefined && j.threads) {
            var ft = j.threads[j.faultingThread];
            console.log('faultingThread=' + j.faultingThread + ' frames=' + (ft.frames? ft.frames.length : 0));
        }
        if (j.lastExceptionBacktrace) {
            console.log('--- lastExceptionBacktrace (符号) ---');
            var imgs = j.usedImages || [];
            var bt = j.lastExceptionBacktrace;
            var maxf = Math.min(bt.length, 25);
            for (var k = 0; k < maxf; k++) {
                var fr = bt[k];
                var img = imgs[fr.imageIndex];
                var imgName = img ? (img.name || img.path) : '?';
                console.log('  #' + k + ' ' + imgName + '  ' + (fr.symbol || ('+' + fr.imageOffset)));
            }
        }
        // 全文里搜 MyGestures / MG 关键字
        var mgIdx = s.indexOf('MyGestures');
        console.log('--- 正文含 MyGestures: ' + (mgIdx >= 0 ? '是' : '否'));
        var mg2 = s.indexOf('MGSettings');
        console.log('--- 正文含 MGSettings: ' + (mg2 >= 0 ? '是' : '否'));
        var mg3 = s.indexOf('unrecognized selector');
        console.log('--- 正文含 unrecognized selector: ' + (mg3 >= 0 ? '是' : '否'));
        if (mg3 >= 0) console.log('  片段: ' + s.substring(mg3 - 50, mg3 + 200).replace(/\n/g, ' '));
    } catch (e) {
        console.log('JSON 解析失败: ' + e + ' , 打印原始片段');
        var idx = s.indexOf('asi');
        console.log(s.substring(idx >= 0 ? idx - 20 : 0, (idx >= 0 ? idx : 0) + 600));
    }
}
console.log('[done]');
