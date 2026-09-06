var jbroot = null;
Process.enumerateModules().forEach(function (m) {
    if (!jbroot) { var match = m.path.match(/^.*\.jbroot-[0-9A-Fa-f]+/); if (match) jbroot = match[0]; }
});
var dir = jbroot + '/usr/lib/TweakInject';
var fm = ObjC.classes.NSFileManager.defaultManager();
var files = fm.contentsOfDirectoryAtPath_error_(dir, Memory.alloc(Process.pointerSize));
console.log('[*] 目录: ' + dir);
console.log('[*] 文件数: ' + (files ? files.count() : 'null'));
if (files) {
    var hits = 0;
    for (var i = 0; i < files.count(); i++) {
        var f = files.objectAtIndex_(i) + '';
        if (!f.endsWith('.dylib') && f.indexOf('.') >= 0) continue;
        try {
            var s = ObjC.classes.NSString.stringWithContentsOfFile_encoding_error_(dir + '/' + f, 4, Memory.alloc(Process.pointerSize));
            if (!s) continue;
            var str = s + '';
            var h1 = str.indexOf('预设链接') >= 0, h2 = str.indexOf('打开应用') >= 0, h3 = str.indexOf('选择动作') >= 0;
            if (h1 || h2 || h3) { hits++; console.log('*** 命中: ' + f + ' (预设链接:' + h1 + ' 打开应用:' + h2 + ' 选择动作:' + h3 + ')'); }
        } catch (e) {}
    }
    console.log('[done] 命中 ' + hits);
}
