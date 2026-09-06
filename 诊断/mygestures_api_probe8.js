// 探测8: 实弹验证 openApplication 新通路 (FBSystemServiceOpenApplicationRequest + FBSSystemService)
// 以及 AVSystemController 音量方法签名
// 用法: timeout 15 frida -U -n SpringBoard -l mygestures_api_probe8.js -q < /dev/null
// 注意: 若通路有坑, SpringBoard 可能再注销一次

try {
    var reqCls = ObjC.classes.FBSystemServiceOpenApplicationRequest;
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var req = reqCls['- initWithBundleId:'].call(reqCls.alloc(), 'com.apple.Preferences');
    console.log('[req] ' + req);
    // trusted 置是, 避免打开受限
    if (req.respondsToSelector(ObjC.selector('setTrusted:'))) req.setTrusted_(1);
    console.log('[调用] openApplication:options:withResult: (com.apple.Preferences)');
    svc['- openApplication:options:withResult:'](req, NULL, NULL);
    console.log('[OK] 调用返回未崩 —— 若手机弹出设置页, 通路验证通过');
} catch (e) { console.log('[openApp] ERR: ' + e); }

// 音量方法签名验证: 0 步进调用 (听感无变化, 只验证不崩不抛)
try {
    var av = ObjC.classes.AVSystemController['+ sharedAVSystemController']();
    console.log('[av] ' + av);
    try {
        av['- changeActiveCategoryVolumeBy:'](0.0);
        console.log('[vol] changeActiveCategoryVolumeBy: 可调用');
    } catch (e) { console.log('[vol] changeActiveCategoryVolumeBy: 异常: ' + e); }
} catch (e) { console.log('[av] ERR: ' + e); }
console.log('[done]');
