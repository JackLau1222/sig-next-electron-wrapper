#!/bin/bash

TOOLS_VERSION="4.0.0"

set -x

SELF=$(readlink -f "$0")
BUILD_DIR=${SELF%/*}
ARCH=$(uname -m)
icon_url=""

## Writeable Envs
{
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
}

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
{
    res_path="$APP_DIR/res"
    icons_path="$APP_DIR/res/entries/icons/hicolor/128x128/apps"
    desktop_file_path="$APP_DIR/res/entries/applications"
    mkdir -p $icons_path $desktop_file_path
    convert -resize 128x128! $res_sources/icon-origin.png $icons_path/$PACKAGE.png
}

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

    pushd "$APP_DIR/files/resources"

    tar -caf resources.tar.zst ./app.asar
    mv resources.tar.zst $APP_DIR/bins

    pushd "$APP_DIR/out"
    mv linux-unpacked $PACKAGE

    tar -caf app-binary-$ARCH.tar.zst ./$PACKAGE
    mv app-binary-$ARCH.tar.zst $APP_DIR/bins
}

    popd

    rm -rf $APP_DIR/entries/icons/hicolor/**/apps/icon.png


## deb packing preparing
### Init build dir for the app
{
    deb_build_dir="$APP_DIR/deb-build-pool/$PACKAGE-$VERSION"
    deb_app_dir="$deb_build_dir/opt/apps/$PACKAGE/"
    mkdir -p $deb_build_dir $deb_app_dir/files

    pushd "$deb_build_dir"

    dh_make --createorig -s -n -y
    rm debian/*.ex debian/*.EX
    rm -rf debian/*.docs debian/README debian/README.*
}

## Generate deb build dir res
{
    mkdir -p $deb_app_dir/files/$PACKAGE/resources

    tar -I zstd -xvf $APP_DIR/bins/resources.tar.zst\
 -C $deb_app_dir/files/$PACKAGE/resources/


    cp -r $res_path/* $deb_app_dir/
}

### Generate control
{
    rm -rf $deb_build_dir/debian/control
    cat <<EOF >$deb_build_dir/debian/control
Source: $PACKAGE
Section: games
Priority: optional
Maintainer: Next Electron Wrapper <lu1044100652@outlook.com>
Vendor: ziggy1030 <lu1044100652@outlook.com>
Build-Depends: debhelper (>= 11)
Standards-Version: 4.1.3
Homepage: $HOMEPAGE

Package: $PACKAGE
Architecture: any
Version: $VERSION
Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0, com.electron.lts (>= 28.3.3)
Description: $NAME is an online mini-game provided by the Poki platform.
EOF
}

### Generate postinst
#{
#    rm -rf $deb_build_dir/debian/postinst
#    cat <<EOF >$deb_build_dir/debian/postinst
##!/bin/bash
#
## SUID chrome-sandbox for Electron 5+
#chmod 4755 '/opt/apps/$PACKAGE/files/$PACKAGE/chrome-sandbox' || true
#EOF
#}

### Generate install file
    rm -rf $deb_build_dir/debian/install
    echo "opt/ /" > $deb_build_dir/debian/install



## Generate deb app dir res
### Generate info file
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

### desktop file
{
    mkdir -p "$deb_app_dir/entries/applications"
    cat <<EOF >$deb_app_dir/entries/applications/$PACKAGE.desktop
[Desktop Entry]
Name=$NAME
Name[zh_CN]=$NAME_CN
Comment=$NAME is an online mini-game provided by the Poki platform.
Comment[zh_CN]=$NAME_CN 是Poki平台提供的一款在线小型游戏.
Exec=/opt/apps/$PACKAGE/files/AppRun %U
Icon=$PACKAGE
Type=Application
Categories=Games;
StartupWMClass=$PACKAGE

Terminal=false
StartupNotify=true
EOF
}

### AppRun
{
    cat <<EOF >$deb_app_dir/files/AppRun
#!/bin/bash

cd /opt/apps/$PACKAGE/files/$PACKAGE
exec /opt/apps/com.electron.lts/files/Electron/electron ./resources/app.asar "\$@"
EOF
}

    chmod +x $deb_app_dir/files/AppRun

## deb Packing

    debuild -b -us -uc -tc

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