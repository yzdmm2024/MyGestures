console.log('===== 类名含 WiFi / Wifi =====');
Object.keys(ObjC.classes).filter(function (c) { return /WiFi|Wifi/i.test(c) && /WF|SB/.test(c.substring(0,2)); }).slice(0, 15)
    .forEach(function (c) { console.log('  ' + c); });
console.log('===== 类名含 Battery (SB/CC/BK开头) =====');
Object.keys(ObjC.classes).filter(function (c) { return /Battery/i.test(c) && /^(SB|CC|BK|PS)/.test(c); }).slice(0, 12)
    .forEach(function (c) { console.log('  ' + c); });
console.log('[done]');
