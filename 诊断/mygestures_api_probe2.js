// 探测第二轮: 截屏手势管理器 / 媒体EventSource方法 / FBSOpenApplication / scene 获取
// 用法: timeout 15 frida -U -n SpringBoard -l mygestures_api_probe2.js -q < /dev/null

function probe(clsName, re, max) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, max || 14);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR ' + clsName + ': ' + e); }
}

probe('SBInteractiveScreenshotGestureManager', /./i, 40);
probe('CHSScreenshotManager', /apture|creenshot/i, 14);
probe('SBMediaController', /EventSource/i, 20);
probe('FBSOpenApplicationService', /open|quest/i, 14);
probe('FBSOpenApplicationRequest', /request|undle/i, 10);

// SB 里 UIApplication 的 scene 获取可行性
try {
    var app = ObjC.classes.UIApplication.sharedApplication();
    var scenes = app.connectedScenes();
    console.log('[scene] connectedScenes count=' + scenes.count() + ' anyObject=' + scenes.anyObject());
} catch (e) { console.log('[scene] ERR: ' + e); }
console.log('[done]');
