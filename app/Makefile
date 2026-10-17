# ---------------------------------------------------------------------------
#  Tube9 -- cliente de YouTube para iOS 9.3.5 (32 bits, armv7)
#  Compilado con Theos + iPhoneOS9.3.sdk en Linux (GitHub Actions, gratis).
#  Ver README.md en la raiz del repositorio.
# ---------------------------------------------------------------------------

# plataforma:compilador:sdk_del_sistema:version_minima
#   9.3 -> usa $THEOS/sdks/iPhoneOS9.3.sdk
#   9.0 -> -miphoneos-version-min=9.0 (todo dispositivo con 9.3.5 lo cumple)
TARGET = iphone:clang:9.3:9.0

# iPhone 4S/5/5C, iPad 2/3/4, iPad mini 1 y iPod touch 5G son de 32 bits.
ARCHS = armv7

# Empaquetado directo a .ipa (requiere el fichero 'control' de al lado).
PACKAGE_FORMAT = ipa

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Tube9

Tube9_FILES = \
	main.m \
	AppDelegate.m \
	YTTheme.m \
	YTVideo.m \
	YTClient.m \
	YTSearchViewController.m \
	YTVideoCell.m \
	YTPlayerViewController.m \
	YTSettingsViewController.m \
	YTLoginViewController.m

Tube9_FRAMEWORKS = UIKit Foundation CoreGraphics AVFoundation AVKit
Tube9_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-parameter
Tube9_RESOURCE_DIRS = Resources

# Todo lo que hay en Resources/ (Info.plist, iconos, imagenes de arranque) se
# copia a la raiz del .app.  Theos hace esto automaticamente.
Tube9_LDFLAGS = -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/application.mk
