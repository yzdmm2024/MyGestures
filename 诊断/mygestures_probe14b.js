// 段2: 4秒后检查设置进程是否被拉起
function prefCount() {
    try {
        var mgr = ObjC.classes.FBProcessManager['+ sharedInstance']();
        var arr = mgr.processesForBundleIdentifier_('com.apple.Preferences');
        return arr ? arr.count() : -1;
    } catch (e) { return 'ERR ' + e; }
}
console.log('[4秒后] 设置进程数: ' + prefCount() + '  (≥1 = openURL 真的能用, 0 = 哑火)');
