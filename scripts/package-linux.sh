#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

# Support Ayatana pkg-config fallback if extracted in /tmp
if [ -d "/tmp/ayatana/root/usr/lib64/pkgconfig" ]; then
  export PKG_CONFIG_PATH="/tmp/ayatana/root/usr/lib64/pkgconfig:${PKG_CONFIG_PATH}"
fi

echo "Building DevStack for Linux..."
flutter build linux --release

mkdir -p dist

echo "Packaging into tarball..."
tar -czf dist/ponta-dev-stack-linux-x64.tar.gz -C build/linux/x64/release/bundle .
echo "Tarball complete: dist/ponta-dev-stack-linux-x64.tar.gz"

echo "Packaging into AppImage..."
APPDIR="build/AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}"

# Copy bundle contents
cp -r build/linux/x64/release/bundle/* "${APPDIR}/"

# Bundle Ayatana & dbusmenu shared libraries if available on host system
for libpath in /usr/lib64/libayatana* /usr/lib64/libdbusmenu* /usr/lib/x86_64-linux-gnu/libayatana* /usr/lib/x86_64-linux-gnu/libdbusmenu*; do
  if [ -e "$libpath" ]; then
    cp -P "$libpath" "${APPDIR}/lib/" 2>/dev/null || true
  fi
done

# Setup AppDir desktop & icon
cp assets/images/icon.png "${APPDIR}/com.ponta.dev_stack.png"
ln -sf com.ponta.dev_stack.png "${APPDIR}/.DirIcon"

cat << 'EOF' > "${APPDIR}/com.ponta.dev_stack.desktop"
[Desktop Entry]
Name=Ponta DevStack
Comment=Local development stack
Exec=dev_stack %U
Icon=com.ponta.dev_stack
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=com.ponta.dev_stack
EOF

cat << 'EOF' > "${APPDIR}/AppRun"
#!/usr/bin/env bash
set -e
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/dev_stack" "$@"
EOF
chmod +x "${APPDIR}/AppRun"

# Locate or download appimagetool
APPIMAGETOOL=""
if command -v appimagetool >/dev/null 2>&1; then
  APPIMAGETOOL="appimagetool"
elif [ -x "/tmp/appimagetool-x86_64.AppImage" ]; then
  APPIMAGETOOL="/tmp/appimagetool-x86_64.AppImage"
else
  echo "Downloading appimagetool..."
  curl -L -o /tmp/appimagetool-x86_64.AppImage https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x /tmp/appimagetool-x86_64.AppImage
  APPIMAGETOOL="/tmp/appimagetool-x86_64.AppImage"
fi

OUTPUT_APPIMAGE="dist/ponta-dev-stack-linux-x64.AppImage"
rm -f "${OUTPUT_APPIMAGE}"

ARCH=x86_64 "${APPIMAGETOOL}" --appimage-extract-and-run --no-appstream "${APPDIR}" "${OUTPUT_APPIMAGE}"

# Also create symlink dev-stack-linux-x64.AppImage for convenience
ln -sf ponta-dev-stack-linux-x64.AppImage dist/dev-stack-linux-x64.AppImage

echo "AppImage complete: ${OUTPUT_APPIMAGE}"
