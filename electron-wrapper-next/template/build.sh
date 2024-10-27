#!/bin/bash

TOOLS_VERSION="1.2.0"

set -x

SELF=$(readlink -f "$0")
BUILD_DIR=${SELF%/*}
ARCH=$(uname -m)

## Writeable Envs
NODE_PATH=""
export PATH="$NODE_PATH:$PATH"
export ELECTRON_VERSION=""

export PACKAGE=""
export NAME=""
export NAME_CN=""
export VERSION="$ELECTRON_VERSION"
export URL="icon.png::icon-url"
export DO_NOT_UNARCHIVE=1
# autostart,notification,trayicon,clipboard,account,bluetooth,camera,audio_record,installed_apps
export REQUIRED_PERMISSIONS=""

export HOMEPAGE="" # wrapper content
# export DEPENDS="libgconf-2-4, libgtk-3-0, libnotify4, libnss3, libxtst6, xdg-utils, libatspi2.0-0, libdrm2, libgbm1, libxcb-dri3-0, kde-cli-tools | kde-runtime | trash-cli | libglib2.0-bin | gvfs-bin"
export DEPENDS="com.electron"
export SECTION="misc"
export PROVIDE=""
export DESC1="Electron wrapper for $HOMEPAGE"
export DESC2=""

#export INGREDIENTS=(nodejs)

## Generated

### Init build dir for single app
    mkdir -p ${BUILD_DIR}/build-pool
{
    mkdir -p ${BUILD_DIR}/build-pool/$PACKAGE
    APP_DIR=${BUILD_DIR}/build-pool/$PACKAGE
    cp "$BUILD_DIR/templates/index.js" "$APP_DIR/index.js"
    mkdir -p ${APP_DIR}/files/
    cp "${BUILD_DIR}/templates/run.sh" "$APP_DIR/files/run.sh"
    cat "${BUILD_DIR}/templates/package.json" | envsubst >"$APP_DIR/package.json"
}

    pushd "$APP_DIR"

### Building
{
 #   export ELECTRON_MIRROR=https://registry.npmmirror.com/
    npm install 
    npm run build
    mkdir -p $APP_DIR/files/resources/
    cp -RT $APP_DIR/out/linux-unpacked/resources $APP_DIR/files/resources
    mkdir -p "${APP_DIR}/files/userscripts"
    cp "$APP_DIR"/*.js "${APP_DIR}/files/userscripts/"
}

### tar binaries
{
    mkdir -p "$APP_DIR/bins"
    tar -caf $APP_DIR/bins/resources.tar.zst $APP_DIR/files/resources

    mv $APP_DIR/out/linux-unpacked $APP_DIR/$PACKAGE
    tar -caf $APP_DIR/bins/app-binary-$ARCH.tar.zst $APP_DIR/$PACKAGE
}

    popd

    rm -rf $APP_DIR/entries/icons/hicolor/**/apps/icon.png

    mkdir -p "$APP_DIR/entries/applications"
    cat <<EOF >$APP_DIR/entries/applications/$PACKAGE.desktop
[Desktop Entry]
Name=$NAME
Name[zh_CN]=$NAME_CN
Exec=env PACKAGE=$PACKAGE /opt/apps/$PACKAGE/files/run.sh %U
Terminal=false
Type=Application
Icon=$PACKAGE
StartupWMClass=$PACKAGE
Categories=Games;
EOF
