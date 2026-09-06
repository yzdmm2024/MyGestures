// 零风险: 检查 BKS/FBS 底层服务类与其方法
function probe(clsName, re) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) { console.log('[probe] ' + clsName + ' 不存在'); return; }
        var own = cls.$ownMethods.filter(function (m) { return re.test(m); }).slice(0, 10);
        console.log('[probe] ' + clsName + ': ' + (own.length ? own.join(' | ') : '(无匹配)'));
    } catch (e) { console.log('[probe] ERR: ' + e); }
}
probe('BKSSystemService', /open/i);
probe('FBSSystemService', /open/i);
probe('BKSOpenApplicationRequest', /./i);
console.log('[done]');
