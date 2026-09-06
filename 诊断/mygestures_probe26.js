// 零风险扫描: 读设备 TweakInject 目录全部 dylib 内容, 找含「预设链接/打开应用」菜单字符串的
var fm = ObjC.classes.NSFileManager.defaultManager();
var dir = '/var/jb/usr/lib/TweakInject';
var files = fm.contentsOfDirectoryAtPath_error_(dir, Memory.alloc(Process.pointerSize));
console.log('[*] TweakInject 文件 ' + files.count() + ' 个');
var hits = [];
for (var i = 0; i < files.count(); i++) {
    var f = files.objectAtIndex_(i) + '';
    if (!f.endsWith('.dylib')) continue;
    try {
        var path = dir + '/' + f;
        var s = ObjC.classes.NSString.stringWithContentsOfFile_encoding_error_(path, 4, Memory.alloc(Process.pointerSize));
        if (!s) continue;
        var str = s + '';
        var has1 = str.indexOf('预设链接') >= 0, has2 = str.indexOf('打开应用') >= 0, has3 = str.indexOf('选择动作') >= 0;
        if (has1 || has2 || has3) {
            hits.push(f);
            console.log('*** 命中: ' + f + '  (预设链接:' + has1 + ' 打开应用:' + has2 + ' 选择动作:' + has3 + ')');
        }
    } catch (e) {}
}
console.log('[done] 命中 ' + hits.length + ' 个');
