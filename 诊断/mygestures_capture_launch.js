// 黄金实验: 挂钩 launchIcon 链路, 等用户手动点主屏图标, 抓真实参数
var mw = ObjC.classes.SBMainWorkspace['+ sharedInstance']();
try {
    var icC = ObjC.classes.SBIconController;
    var sel = '- iconManager:launchIcon:location:animated:completionHandler:';
    var impl = icC[sel].implementation;
    Interceptor.attach(impl, {
        onEnter: function (args) {
            console.log('*** launchIcon 被调用 (用户点了图标) ***');
            for (var i = 2; i <= 6; i++) {
                try {
                    var p = args[i];
                    if (p.isNull()) { console.log('  arg' + (i-2) + ' = NULL'); continue; }
                    var o = new ObjC.Object(p);
                    var d = o.description().toString();
                    console.log('  arg' + (i-2) + ' [' + o.$className + '] = ' + d.substring(0, 150));
                } catch (e) { console.log('  arg' + (i-2) + ' 原始值: ' + p); }
            }
        }
    });
    console.log('[hook] launchIcon 已挂 —— 现在去主屏点一个 App 图标');
} catch (e) { console.log('[hook] ERR: ' + e); }
console.log('[done-ready] 30 秒内点击主屏任意图标');
