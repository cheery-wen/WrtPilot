
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-wrtpilot
PKG_VERSION:=2026.11.24
PKG_RELEASE:=1
PKG_LICENSE:=GPL-3.0-only
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=cheery-wen

LUCI_TITLE:=WrtPilot Firmware Upgrade Pilot
LUCI_DEPENDS:=+luci-base +wget-ssl +ca-bundle
LUCI_PKGARCH:=all

ifneq ($(wildcard $(TOPDIR)/feeds/luci/luci.mk),)
  include $(TOPDIR)/feeds/luci/luci.mk
else
  include ../../luci.mk
endif

# call BuildPackage - OpenWrt buildroot signature
