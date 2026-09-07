// 探测: 控制中心打开 + CC 相机模块
function dump(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
console.log('===== 类名含 ControlCenter =====');
Object.keys(ObjC.classes).filter(function (c) { return /ControlCenter/i.test(c) && /^(SB|CC)/.test(c); }).slice(0, 10)
    .forEach(function (c) { console.log('  ' + c); });
dump('SBControlCenterController', /isible|pen|how/i, 12);
console.log('===== 类名含 CameraModule / CCModule =====');
Object.keys(ObjC.classes).filter(function (c) { return /(CameraModule|CCModule)/i.test(c); }).slice(0, 12)
    .forEach(function (c) { console.log('  ' + c); });
console.log('[done]');
