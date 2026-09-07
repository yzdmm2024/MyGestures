// 探针: 寻找 iOS 16 秒开相机的类和方法
// 挂在手机 SpringBoard 上: frida -U SpringBoard -l 本文件

function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 14);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}

console.log('========================================');
console.log('1. SBCameraHardwareButton 全部方法');
console.log('========================================');
dump('SBCameraHardwareButton', /./i, 30);

console.log('\n========================================');
console.log('2. 类名含 CameraModule / CCModule / Camera 的 SB 类');
console.log('========================================');
Object.keys(ObjC.classes).filter(function (c) {
    return /(CameraModule|CCModule|SBCamera)/i.test(c) && c.indexOf('SB') === 0;
}).slice(0, 20).forEach(function (c) { console.log('  ' + c); });

console.log('\n========================================');
console.log('3. SBUIController 启动相关方法');
console.log('========================================');
dump('SBUIController', /activate|launch|camera/i, 20);

console.log('\n========================================');
console.log('4. SBControlCenterController 模块相关方法');
console.log('========================================');
dump('SBControlCenterController', /module|camera|present|visible/i, 20);

console.log('\n========================================');
console.log('5. 类名含 CCUI 的类 (控制中心模块)');
console.log('========================================');
Object.keys(ObjC.classes).filter(function (c) {
    return /^CCUI/.test(c);
}).slice(0, 30).forEach(function (c) { console.log('  ' + c); });

console.log('\n========================================');
console.log('6. SBShortcutController (锁屏快捷方式)');
console.log('========================================');
dump('SBShortcutController', /./i, 20);
var sc = ObjC.classes.SBShortcutController;
if (sc) {
    try {
        var s = sc['+ sharedInstance']();
        console.log('[sharedInstance] ' + s);
    } catch(e) { console.log('[sharedInstance ERR] ' + e); }
}

console.log('\n========================================');
console.log('7. 类名含 Shortcut 的 SB 类');
console.log('========================================');
Object.keys(ObjC.classes).filter(function (c) {
    return /Shortcut/i.test(c) && c.indexOf('SB') === 0;
}).slice(0, 10).forEach(function (c) { console.log('  ' + c); });

console.log('\n[done]');