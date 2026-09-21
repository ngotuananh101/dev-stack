#!/bin/sh
# Post-install hook for the Linux .deb / .rpm packages (shared by fpm).
#
# Installing a .desktop file and an icon under /usr/share is not enough on
# its own: desktop environments read a cached index, so without refreshing
# it the app can be missing from the application menu until the user logs
# out and back in. These commands are the standard distro behaviour
# (Debian's dh_installmenu and Fedora's scriptlets do the same).
#
# Every command is best-effort: on a minimal/headless system some of these
# tools do not exist, and a missing cache refresh must never fail the
# package installation.

if [ -x "$(command -v update-desktop-database)" ]; then
    update-desktop-database -q /usr/share/applications >/dev/null 2>&1 || true
fi

if [ -x "$(command -v gtk-update-icon-cache)" ]; then
    gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

if [ -x "$(command -v xdg-desktop-menu)" ]; then
    xdg-desktop-menu forceupdate >/dev/null 2>&1 || true
fi

exit 0
