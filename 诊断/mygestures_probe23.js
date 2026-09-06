// 逐步 typeof 定位
var ic = ObjC.classes.SBIconController['+ sharedInstance']();
console.log('typeof ic.model: ' + typeof ic.model);
console.log('typeof ic.iconManager: ' + typeof ic.iconManager);
console.log('typeof model.applicationIconForBundleIdentifier_: ' + (function(){ try { var m = ic.model(); return typeof m.applicationIconForBundleIdentifier_; } catch (e) { return 'model获取失败:' + e; } })());
// 也列出 model/model 相关真实名字
ObjC.classes.SBIconController.$ownMethods.filter(function (m) { return /odel|anager/i.test(m); }).slice(0, 10).forEach(function (m) { console.log('  own: ' + m); });
console.log('[done]');
