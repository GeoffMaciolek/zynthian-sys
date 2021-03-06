#!/bin/bash

if [ -d "$ZYNTHIAN_CONFIG_DIR" ]; then
	source "$ZYNTHIAN_CONFIG_DIR/zynthian_envars.sh"
else
	source "$ZYNTHIAN_SYS_DIR/scripts/zynthian_envars.sh"
fi

echo "Updating System configuration ..."

#------------------------------------------------------------------------------
# Define some functions
#------------------------------------------------------------------------------

function custom_config {
	echo "Custom Config $1 ..."
	cd "$1"
	if [ -d "etc" ]; then
		for file in etc/* ; do
			if [ "$file" = "etc/modules" ]; then
				cat "$file" >> /etc/modules
			else
				cp -a "$file" /etc
			fi
		done
	fi
	if [ -d "boot" ]; then
		for file in boot/* ; do
			cp -a "$file" /boot
		done
	fi
	if [ -d "config" ]; then
		for file in config/* ; do
			cp -a "$file" $ZYNTHIAN_CONFIG_DIR
		done
	fi
}

#------------------------------------------------------------------------------
# Default Values for some Config Variables
#------------------------------------------------------------------------------

if [ -z "$ZYNTHIAN_CONFIG_DIR" ]; then
	export ZYNTHIAN_CONFIG_DIR="$ZYNTHIAN_DIR/config"
fi

if [ -z "$FRAMEBUFFER" ]; then
	export FRAMEBUFFER="/dev/fb1"
fi

if [ -z "$JACKD_OPTIONS" ]; then
	export JACKD_OPTIONS="-P 70 -t 2000 -s -d alsa -d hw:0 -r 44100 -p 256 -n 2 -X raw"
fi

if [ -z "$ZYNTHIAN_AUBIONOTES_OPTIONS" ]; then
	export ZYNTHIAN_AUBIONOTES_OPTIONS="-O complex -t 0.5 -s -88  -p yinfft -l 0.5"
fi

#------------------------------------------------------------------------------
# Escape Config Variables to replace
#------------------------------------------------------------------------------

FRAMEBUFFER_ESC=${FRAMEBUFFER//\//\\\/}
LV2_PATH_ESC=${LV2_PATH//\//\\\/}
ZYNTHIAN_DIR_ESC=${ZYNTHIAN_DIR//\//\\\/}
ZYNTHIAN_CONFIG_DIR_ESC=${ZYNTHIAN_CONFIG_DIR//\//\\\/}
ZYNTHIAN_SYS_DIR_ESC=${ZYNTHIAN_SYS_DIR//\//\\\/}
ZYNTHIAN_UI_DIR_ESC=${ZYNTHIAN_UI_DIR//\//\\\/}
ZYNTHIAN_SW_DIR_ESC=${ZYNTHIAN_SW_DIR//\//\\\/}
JACKD_OPTIONS_ESC=${JACKD_OPTIONS//\//\\\/}
ZYNTHIAN_AUBIONOTES_OPTIONS_ESC=${ZYNTHIAN_AUBIONOTES_OPTIONS//\//\\\/}

#------------------------------------------------------------------------------
# Boot Config 
#------------------------------------------------------------------------------

cp $ZYNTHIAN_SYS_DIR/boot/cmdline.txt /boot

# Detect NO_ZYNTHIAN_UPDATE flag
if [ -f "/boot/config.txt" ]; then
	no_update_config=`grep -e ^#NO_ZYNTHIAN_UPDATE /boot/config.txt`
fi

if [ -z "$no_update_config" ]; then
	cp $ZYNTHIAN_SYS_DIR/boot/config.txt /boot

	echo "SOUNDCARD CONFIG => $SOUNDCARD_CONFIG"
	sed -i -e "s/#SOUNDCARD_CONFIG#/$SOUNDCARD_CONFIG/g" /boot/config.txt
	
	echo "DISPLAY CONFIG => $DISPLAY_CONFIG"
	sed -i -e "s/#DISPLAY_CONFIG#/$DISPLAY_CONFIG/g" /boot/config.txt
fi

# Copy extra overlays
cp -a $ZYNTHIAN_SYS_DIR/boot/overlays/* /boot/overlays

#------------------------------------------------------------------------------
# System Config 
#------------------------------------------------------------------------------

# Copy "etc" config files
cp -a $ZYNTHIAN_SYS_DIR/etc/modules /etc
cp -a $ZYNTHIAN_SYS_DIR/etc/inittab /etc
cp -a $ZYNTHIAN_SYS_DIR/etc/network/* /etc/network
cp -an $ZYNTHIAN_SYS_DIR/etc/wpa_supplicant/* /etc/wpa_supplicant
cp -a $ZYNTHIAN_SYS_DIR/etc/dbus-1/* /etc/dbus-1
cp -a $ZYNTHIAN_SYS_DIR/etc/systemd/* /etc/systemd/system
cp -a $ZYNTHIAN_SYS_DIR/etc/udev/rules.d/* /etc/udev/rules.d

# X11 Display config
if [ ! -d "/etc/X11/xorg.conf.d" ]; then
	mkdir /etc/X11/xorg.conf.d
fi
cp -a $ZYNTHIAN_SYS_DIR/etc/X11/xorg.conf.d/99-fbdev.conf /etc/X11/xorg.conf.d
sed -i -e "s/#FRAMEBUFFER#/$FRAMEBUFFER_ESC/g" /etc/X11/xorg.conf.d/99-fbdev.conf

# Fix problem with WLAN interfaces numbering
if [ ! -f "/etc/udev/rules.d/70-persistent-net.rules" ]; then
	mv /etc/udev/rules.d/70-persistent-net.rules /etc/udev/rules.d/70-persistent-net.rules.inactive
fi

# Copy fonts to system directory
cp -an $ZYNTHIAN_UI_DIR/fonts/* /usr/share/fonts/truetype

# User Config (root)
# => ZynAddSubFX Config
cp -a $ZYNTHIAN_SYS_DIR/etc/zynaddsubfxXML.cfg /root/.zynaddsubfxXML.cfg

# Zynthian Specific Config Files
if [ ! -d "$ZYNTHIAN_CONFIG_DIR" ]; then
	mkdir $ZYNTHIAN_CONFIG_DIR
fi
if [ ! -f "$ZYNTHIAN_CONFIG_DIR/zynthian_envars.sh" ]; then
	cp -a $ZYNTHIAN_SYS_DIR/scripts/zynthian_envars.sh $ZYNTHIAN_CONFIG_DIR
fi
if [ ! -f "$ZYNTHIAN_CONFIG_DIR/backup_items.txt" ]; then
	cp -a $ZYNTHIAN_SYS_DIR/etc/backup_items.txt $ZYNTHIAN_CONFIG_DIR
fi
rm -f $ZYNTHIAN_CONFIG_DIR/zynthian_custom_config.sh

# Device Custom files
display_config_custom_dir="$ZYNTHIAN_SYS_DIR/custom/display/$DISPLAY_NAME"
if [ -d "$display_config_custom_dir" ]; then
	custom_config "$display_config_custom_dir"
fi
soundcard_config_custom_dir="$ZYNTHIAN_SYS_DIR/custom/soundcard/$SOUNDCARD_NAME"
if [ -d "$soundcard_config_custom_dir" ]; then
	custom_config "$soundcard_config_custom_dir"
fi

# Replace config vars in Systemd service files
# Cpu-performance service
sed -i -e "s/#ZYNTHIAN_SYS_DIR#/$ZYNTHIAN_SYS_DIR_ESC/g" /etc/systemd/system/cpu-performance.service
# Splash-Screen Service
sed -i -e "s/#FRAMEBUFFER#/$FRAMEBUFFER_ESC/g" /etc/systemd/system/splash-screen.service
sed -i -e "s/#ZYNTHIAN_DIR#/$ZYNTHIAN_DIR_ESC/g" /etc/systemd/system/splash-screen.service
sed -i -e "s/#ZYNTHIAN_UI_DIR#/$ZYNTHIAN_UI_DIR_ESC/g" /etc/systemd/system/splash-screen.service
sed -i -e "s/#ZYNTHIAN_SYS_DIR#/$ZYNTHIAN_SYS_DIR_ESC/g" /etc/systemd/system/splash-screen.service
sed -i -e "s/#ZYNTHIAN_CONFIG_DIR#/$ZYNTHIAN_CONFIG_DIR_ESC/g" /etc/systemd/system/splash-screen.service
# Zynthian Service
sed -i -e "s/#FRAMEBUFFER#/$FRAMEBUFFER_ESC/g" /etc/systemd/system/zynthian.service
sed -i -e "s/#ZYNTHIAN_DIR#/$ZYNTHIAN_DIR_ESC/g" /etc/systemd/system/zynthian.service
sed -i -e "s/#ZYNTHIAN_UI_DIR#/$ZYNTHIAN_UI_DIR_ESC/g" /etc/systemd/system/zynthian.service
sed -i -e "s/#ZYNTHIAN_SYS_DIR#/$ZYNTHIAN_SYS_DIR_ESC/g" /etc/systemd/system/zynthian.service
sed -i -e "s/#ZYNTHIAN_CONFIG_DIR#/$ZYNTHIAN_CONFIG_DIR_ESC/g" /etc/systemd/system/zynthian.service
# Zynthian Webconf Service
sed -i -e "s/#ZYNTHIAN_DIR#/$ZYNTHIAN_DIR_ESC/g" /etc/systemd/system/zynthian-webconf.service
sed -i -e "s/#ZYNTHIAN_CONFIG_DIR#/$ZYNTHIAN_CONFIG_DIR_ESC/g" /etc/systemd/system/zynthian-webconf.service
# Jackd service
sed -i -e "s/#JACKD_OPTIONS#/$JACKD_OPTIONS_ESC/g" /etc/systemd/system/jack2.service
# MOD-HOST service
sed -i -e "s/#LV2_PATH#/$LV2_PATH_ESC/g" /etc/systemd/system/mod-host.service
# MOD-SDK service
sed -i -e "s/#LV2_PATH#/$LV2_PATH_ESC/g" /etc/systemd/system/mod-sdk.service
sed -i -e "s/#ZYNTHIAN_SW_DIR#/$ZYNTHIAN_SW_DIR_ESC/g" /etc/systemd/system/mod-sdk.service
# MOD-UI service
sed -i -e "s/#LV2_PATH#/$LV2_PATH_ESC/g" /etc/systemd/system/mod-ui.service
sed -i -e "s/#ZYNTHIAN_SW_DIR#/$ZYNTHIAN_SW_DIR_ESC/g" /etc/systemd/system/mod-ui.service
# Aubionotes service
sed -i -e "s/#ZYNTHIAN_AUBIONOTES_OPTIONS#/$ZYNTHIAN_AUBIONOTES_OPTIONS_ESC/g" /etc/systemd/system/aubionotes.service
