ARCHS = arm64 armv7
#ARCHS = x86_64 i386
TARGET = iphone
#TARGET = macosx
include $(THEOS_MAKE_PATH)/common.mk
TOOL_NAME = uncar
uncar_FILES = main.mm
uncar_FRAMEWORKS = UIKit CoreGraphics
#uncar_FRAMEWORKS = AppKit
include $(THEOS_MAKE_PATH)/tool.mk
