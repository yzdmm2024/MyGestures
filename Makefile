# ============ MyGestures：rootless tweak + 设置面板 ============
# 照「系统-设置出现面板菜单的方法/模板」的已验证写法（键盘下方状态 v1.0.3 同款）
# 坑G：必须用 theos/sdks 的 14.5 SDK，新 Xcode SDK 无私有框架 tbd，链不了 Preferences
TARGET := iphone:clang:14.5:14.0
# 坑F：arm64e 设备（12 Pro = A14）的「设置」进程跑 arm64e，纯 arm64 bundle 加载报
#      「已损坏或丢失必要的资源」，必须双切片
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

# ===== Tweak 本体（手势识别 + 动作执行）=====
TWEAK_NAME = MyGestures
MyGestures_FILES = Tweak.x
MyGestures_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -w
MyGestures_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation QuartzCore AudioToolbox CoreHaptics

# ===== 设置面板 PreferenceBundle =====
# 入口 plist：layout/Library/PreferenceLoader/Preferences/MyGesturesPrefs.plist
# Info/Root：layout/Library/PreferenceBundles/MyGesturesPrefs.bundle/（<Bundle>_RESOURCES 声明不生效，必须手放）
BUNDLE_NAME = MyGesturesPrefs
MyGesturesPrefs_FILES = Preferences/MGSettingsController.m Preferences/MGBlacklistController.m Preferences/MGActionPickerController.m Preferences/MGAppPickerController.m Preferences/MGLinksController.m
MyGesturesPrefs_INSTALL_PATH = /Library/PreferenceBundles
MyGesturesPrefs_FRAMEWORKS = UIKit Foundation QuartzCore
# 坑E：必须显式链接 Preferences（chained fixups 下 dynamic_lookup 会被 dyld 拒载）
MyGesturesPrefs_PRIVATE_FRAMEWORKS = Preferences
# 坑E：theos 只发 -framework 不发搜索路径，必须补 -F
MyGesturesPrefs_LDFLAGS = -F$(TARGET_PRIVATE_FRAMEWORK_PATH)
MyGesturesPrefs_CFLAGS = -fobjc-arc -fobjc-exceptions -w

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
