TARGET := iphone:clang:16.5:14.0
ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FuckGif

FuckGif_FILES = FuckGif.xm FuckGifManager.m
FuckGif_CFLAGS = -fobjc-arc -Wno-error=deprecated-declarations -Wno-error=deprecated-implementations
FuckGif_FRAMEWORKS = UIKit Photos AVFoundation ImageIO MobileCoreServices
FuckGif_LIBRARIES = MobileGestalt

include $(THEOS_MAKE_PATH)/tweak.mk 