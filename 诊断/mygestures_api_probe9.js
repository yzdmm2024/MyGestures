// 探测9: SBMainWorkspace 内部通路 openApp (最后一条候选)
function probeC(clsName, re) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var copyMethodList = new NativeFunction(Module.findExportByName(null, 'class_copyMethodList'), 'pointer', ['pointer', 'pointer']);
        var methodGetName = new NativeFunction(Module.findExportByName(null, 'method_getName'), 'pointer', ['pointer']);
        var selGetName = new NativeFunction(Module.findExportByName(null, 'sel_getName'), 'pointer', ['pointer']);
        var objectGetClass = new NativeFunction(Module.findExportByName(null, 'object_getClass'), 'pointer', ['pointer']);
        var countPtr = Memory.alloc(4);
        var list = copyMethodList(objectGetClass(cls.$handle ? cls.$handle : cls), countPtr);
        var n = countPtr.readInt(), out = [];
        for (var i = 0; i < n; i++) {
            var m = Memory.readUtf8String(selGetName(methodGetName(list.add(i * Process.pointerSize).readPointer())));
            if (re.test(m)) out.push(m);
        }
        console.log('[probe] ' + clsName + ' 类方法: ' + (out.length ? out.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR: ' + e); }
}
probeC('SBMainWorkspace', /shared|efault|ingleton/i);

try {
    var req = ObjC.classes.FBSystemServiceOpenApplicationRequest.alloc().initWithBundleId_('com.apple.Preferences');
    req.setTrusted_(true);
    var svc = ObjC.classes.FBSSystemService['+ sharedService']();
    var ws = ObjC.classes.SBMainWorkspace['+ sharedInstance']
        ? ObjC.classes.SBMainWorkspace['+ sharedInstance']()
        : ObjC.classes.SBMainWorkspace['+ defaultManager']();
    console.log('[ws] ' + ws);
    console.log('[调用] systemService:handleOpenApplicationRequest:withCompletion: ...');
    ws.systemService_handleOpenApplicationRequest_withCompletion_(svc, req, NULL);
    console.log('[OK] 返回未崩 —— 看手机是否弹出设置');
} catch (e) { console.log('[openApp] ERR: ' + e); }
console.log('[done]');
