// 最终探测: 开应用请求类方法 / 截屏实例持有者
// 用法: timeout 12 frida -U -n SpringBoard -l mygestures_api_probe4.js -q < /dev/null
function probe(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 12);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}
probe('FBSystemServiceOpenApplicationRequest', /./i, 16);
probe('SSScreenCapturer', /apture|creenshot/i, 12);
probe('SBUIController', /creenshot/i, 8);
probe('SBMainWorkspace', /creenshot/i, 8);
probe('SBController', /creenshot|esture/i, 10);
console.log('[done]');
