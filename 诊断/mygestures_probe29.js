// 双编码扫描 TweakInject dylib 文件 (UTF-8 + UTF-16LE) 找悬浮菜单 tweak
var jbroot = null;
Process.enumerateModules().forEach(function (m) {
    if (!jbroot) { var match = m.path.match(/^.*\.jbroot-[0-9A-Fa-f]+/); if (match) jbroot = match[0]; }
});
var dir = jbroot + '/usr/lib/TweakInject';
var fm = ObjC.classes.NSFileManager.defaultManager();
var files = fm.contentsOfDirectoryAtPath_error_(dir, Memory.alloc(Process.pointerSize));

function utf16lePat(s) { // JS string -> UTF-16LE bytes as hex pattern for NSData search
    var bytes = [];
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i);
        bytes.push(c & 0xff, (c >> 8) & 0xff);
    }
    return bytes;
}
function utf8Pat(s) {
    var a = Memory.allocUtf8String(s), bytes = [];
    for (var i = 0; i < s.length * 4; i++) { var b = a.add(i).readU8(); if (!b) break; bytes.push(b); }
    return bytes;
}
function dataHas(nsdata, bytes) {
    var buf = Memory.alloc(bytes.length);
    for (var i = 0; i < bytes.length; i++) buf.add(i).writeU8(bytes[i] & 0xff);
    var pat = ObjC.classes.NSData.dataWithBytes_length_(buf, bytes.length);
    var r = nsdata.rangeOfData_options_range_(pat, 0, NSMakeRange(0, nsdata.length()));
    return r.location != 0xFFFFFFFFFFFFFFFF ? r.location : -1;
}
function NSMakeRange(loc, len) { // 用 NSValue/struct — 简化: 直接构造 NSRange 结构指针
    return null; // 改用 containsNSObject 方式
}
console.log('[*] 文件数 ' + files.count());
for (var i = 0; i < files.count(); i++) {
    var f = files.objectAtIndex_(i) + '';
    if (f.indexOf('.dylib') < 0) continue;
    try {
        var d = ObjC.classes.NSData.dataWithContentsOfFile_(dir + '/' + f);
        if (!d || d.length() < 1000) continue;
        // UTF-8 检查: 转字符串 indexOf
        var s = ObjC.classes.NSString.alloc().initWithData_encoding_(d, 4);
        var u8hit = s && ((s + '').indexOf('预设链接') >= 0 || (s + '').indexOf('选择动作') >= 0);
        // UTF-16LE 检查: 手动扫字节
        var p16 = utf16lePat('预设链接'), u16hit = false;
        if (s) {
            var str16 = ObjC.classes.NSString.alloc().initWithData_encoding_(d, NSUTF16LittleEndianStringEncoding || 0x94000100);
            u16hit = str16 && ((str16 + '').indexOf('预设链接') >= 0 || (str16 + '').indexOf('选择动作') >= 0);
        }
        if (u8hit || u16hit) console.log('*** 命中: ' + f + ' (u8:' + u8hit + ' u16:' + u16hit + ')');
    } catch (e) {}
}
console.log('[done]');
