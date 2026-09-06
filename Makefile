# MyGestures Makefile (Theos)
# rootless 越狱 (Relaxin / Dopamine 系) 必须用 rootless 打包方案
export THEOS_PACKAGE_SCHEME = rootless

# 目标: iOS 16.5 SDK, 最低支持 iOS 16.0, arm64
TARGET = iphone:clang:16.5:16.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyGestures

MyGestures_FILES = Tweak.x
MyGestures_CFLAGS = -fobjc-arc
MyGestures_FRAMEWORKS = UIKit AVFoundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

# 把设置面板 (PreferenceLoader) 一并打进 deb, rootless 下会自动映射到 /var/jb
before-package::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp $(THEOS_PROJECT_DIR)/Prefs/MyGestures.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/MyGestures.plist$(ECHO_END)

# 通过 SSH 安装时 (make install) 自动注销生效
after-install:: install.exec "killall -9 SpringBoard"
