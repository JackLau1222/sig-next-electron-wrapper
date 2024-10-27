#!/bin/bash

TOOLS_VERSION="2.3.1"

set -x

SELF=$(readlink -f "$0")
BUILD_DIR=${SELF%/*}
ARCH=$(uname -m)
icon_url=""

## Writeable Envs
NODE_PATH=""
export PATH="$NODE_PATH:$PATH"
export ELECTRON_VERSION=""

export PACKAGE=""
export NAME=""
export NAME_CN=""
export VERSION="$ELECTRON_VERSION"
export URL="icon.png::icon_url"
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
    mkdir -p $BUILD_DIR/build-pool
{
    mkdir -p $BUILD_DIR/build-pool/$PACKAGE
    APP_DIR=$BUILD_DIR/build-pool/$PACKAGE
    cp "$BUILD_DIR/templates/index.js" "$APP_DIR/index.js"
    mkdir -p $APP_DIR/files/
    cp "$BUILD_DIR/templates/run.sh" "$APP_DIR/files/run.sh"
    cat "$BUILD_DIR/templates/package.json" | envsubst >"$APP_DIR/package.json"
}

### Get icons
{
    res_sources="$APP_DIR/res-sources"
    mkdir -p $res_sources
    wget -c $icon_url -O $res_sources/icon-origin.png
}

### Resize icons
    res_path="$APP_DIR/res"
    icons_path="$APP_DIR/res/entries/icons/hicolor/128x128/apps"
    desktop_file_path="$APP_DIR/res/entries/applications"
    mkdir -p $icons_path $desktop_file_path
    convert -resize 128x128! $res_sources/icon-origin.png $icons_path/$PACKAGE.png

    pushd "$APP_DIR"

## Building
{
 #   export ELECTRON_MIRROR=https://registry.npmmirror.com/
    npm install 
    npm run build
    mkdir -p $APP_DIR/files/resources/
    cp -RT $APP_DIR/out/linux-unpacked/resources $APP_DIR/files/resources
    mkdir -p "$APP_DIR/files/userscripts"
    cp "$APP_DIR"/*.js "${APP_DIR}/files/userscripts/"
}

## tar binaries
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

## deb packing
### Init build dir for the app
{
    deb_build_dir="$APP_DIR/deb-build-pool/$PACKAGE-$VERSION"
    deb_app_dir="$deb_build_dir/opt/apps/$PACKAGE/"
    mkdir -p $deb_build_dir $deb_app_dir/files

    pushd "$deb_build_dir"

    dh_make --createorig -s -n -y
}

### Generate deb build dir res
{
    tar -I zstd -xvf $APP_DIR/bins/app-binary-$ARCH.tar.zst\
 -C $deb_app_dir/files/
    cp -RT $res_path/* $deb_app_dir/
}

### info file
{
    cat <<EOF >$deb_app_dir/info
{
  "appid": "$PACKAGE",
  "name": "$NAME",
  "version": "$VERSION",
  "arch": [
    "amd64,arm64"
  ],
  "permissions": {
    "autostart": false,
    "notification": false,
    "trayicon": false,
    "clipboard": true,
    "account": false,
    "bluetooth": false,
    "camera": false,
    "audio_record": false,
    "installed_apps": false
  }
}
EOF
}


### Files copy
{
    mkdir -p $APP_DIR/deb-build-pool
    mkdir -p $BUILD_DIR/build-pool/$PACKAGE
    APP_DIR=$BUILD_DIR/build-pool/$PACKAGE
    cp "$BUILD_DIR/templates/index.js" "$APP_DIR/index.js"
    mkdir -p $APP_DIR/files/
    cp "$BUILD_DIR/templates/run.sh" "$APP_DIR/files/run.sh"
    cat "$BUILD_DIR/templates/package.json" | envsubst >"$APP_DIR/package.json"
}