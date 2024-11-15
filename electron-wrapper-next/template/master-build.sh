#!/bin/bash

TOOLS_VERSION="7.4.4"

set -x

SELF=$(readlink -f "$0")
BUILD_DIR=${SELF%/*}
ARCH=$(uname -m)

## Writeable Envs
{
maintainer_name=""
maintainer_email=""
NODE_PATH=""
build_num=""
ELECTRON_VERSION=""

## Auto-generated
export PATH="$NODE_PATH:$PATH"
export ELECTRON_VERSION=$ELECTRON_VERSION

if [ "${build_num}" == "" ]; then
  export VERSION="${ELECTRON_VERSION}"
  export LL_VERSION="${ELECTRON_VERSION}"
else
  export VERSION="${ELECTRON_VERSION}"
  export LL_VERSION="$ELECTRON_VERSION"."$build_num"
fi
}

## Auto read
while IFS=_ read package name homepage icon_url developer; do

## Envs for npm info
export URL="icon.png::$icon_url"
export NAME=$name
export HOMEPAGE=$homepage
export npm_package=$package
export auth_name=$maintainer_name
export auth_email=$maintainer_email

## Generated
    mkdir -p $BUILD_DIR/build-pool

### Init npm build dir for single app
{
    APP_DIR="$BUILD_DIR/build-pool/$package"
    npm_build_dir="$APP_DIR/npm-build-pool"
    ## Set the electron project arch
    if [ ${ARCH} == "x86_64" ]; then
      export electron_arch="x64"
      unpacked_dir="linux-unpacked"
    elif [ ${ARCH} == "aarch64" ]; then
      export electron_arch="arm64"
      unpacked_dir="linux-arm64-unpacked"
    fi
    mkdir -p $APP_DIR $npm_build_dir
    cp "$BUILD_DIR/templates/index.js" "$npm_build_dir/index.js"
    cat "$BUILD_DIR/templates/package.json" | envsubst >"$npm_build_dir/package.json"
}

### Get 256 icons
{
    res_sources="$APP_DIR/res-sources"
    res_path="$APP_DIR/res"
    mkdir -p $res_sources
    wget -c $icon_url -O $res_sources/icon-origin.png
    icons_256_path="$APP_DIR/res/entries/icons/hicolor/256x256/apps"
    mkdir -p $icons_256_path
    cp $res_sources/icon-origin.png $icons_256_path/$package.png
}

### Resize icons to 128
{
    res_path="$APP_DIR/res"
    icons_128_path="$APP_DIR/res/entries/icons/hicolor/128x128/apps"
    mkdir -p $icons_128_path
    convert -resize 128x128! $res_sources/icon-origin.png $icons_128_path/$package.png
}

    pushd "$npm_build_dir"

## Building
### Install cnpm & Set mirror for Electron
npm install -g cnpm --registry=https://registry.npmmirror.com
export ELECTRON_MIRROR="https://npmmirror.com/mirrors/electron/"

{
    cnpm install 
    cnpm run build
    mkdir -p $npm_build_dir/files/resources/
    cp -RT $npm_build_dir/out/$unpacked_dir/resources $npm_build_dir/files/resources
    mkdir -p "$npm_build_dir/files/userscripts"
    cp "$npm_build_dir"/*.js "${npm_build_dir}/files/userscripts/"
}

## tar binaries
{
    mkdir -p "$APP_DIR/bins"

    pushd "$npm_build_dir/files/resources"

    tar -caf resources.tar.zst ./app.asar
    mv resources.tar.zst $APP_DIR/bins

    pushd "$npm_build_dir/out"
    mv $unpacked_dir $package

    tar -caf app-binary-$ARCH.tar.zst ./$package
    mv app-binary-$ARCH.tar.zst $APP_DIR/bins
}

    popd

    rm -rf $APP_DIR/entries/icons/hicolor/**/apps/icon.png


## deb packing preparing
### Init build dir for the app
{
    deb_build_dir="$APP_DIR/deb-build-pool/$package-$VERSION"
    deb_app_dir="$deb_build_dir/opt/apps/$package/"
    mkdir -p $deb_build_dir $deb_app_dir/files

    pushd "$deb_build_dir"

    dh_make --createorig -s -n -y
    rm debian/*.ex debian/*.EX
    rm -rf debian/*.docs debian/README debian/README.*
}

## Generate deb build dir res
{
    mkdir -p $deb_app_dir/files/$package/resources

    tar -I zstd -xvf $APP_DIR/bins/resources.tar.zst\
 -C $deb_app_dir/files/$package/resources/

    cp -r $res_path/* $deb_app_dir/
}

### Generate control
{
    rm -rf $deb_build_dir/debian/control
    cat <<EOF >$deb_build_dir/debian/control
Source: $package
Section: games
Priority: optional
Maintainer: $maintainer_name <$maintainer_email>
Vendor: Next Electron Wrapper <lu1044100652@outlook.com>
Build-Depends: debhelper (>= 11)
Standards-Version: 4.1.3
Homepage: $homepage

Package: $package
Architecture: any
Version: $VERSION
Depends: libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0, com.electron.lts (>= 28.3.3)
Description: $name is an online mini-game provided by the Poki platform.
EOF
}

### Generate postinst
#{
#    rm -rf $deb_build_dir/debian/postinst
#    cat <<EOF >$deb_build_dir/debian/postinst
##!/bin/bash
#
## SUID chrome-sandbox for Electron 5+
#chmod 4755 '/opt/apps/$package/files/$package/chrome-sandbox' || true
#EOF
#}

### Generate install file
{
    rm -rf $deb_build_dir/debian/install
    echo "opt/ /" > $deb_build_dir/debian/install


### Generate rules
    rm -rf $deb_build_dir/debian/rules
    cp "$BUILD_DIR/templates/rules" "$deb_build_dir/debian/rules"
}

## Generate deb app dir res
### Generate info file
{
    cat <<EOF >$deb_app_dir/info
{
  "appid": "$package",
  "name": "$name",
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
    desktop_file_path="$APP_DIR/res/entries/applications"
    mkdir -p "$deb_app_dir/entries/applications"
    cat <<EOF >$deb_app_dir/entries/applications/$package.desktop
[Desktop Entry]
Name=$name
Name[zh_CN]=$name
Comment=$name is an online mini-game provided by the Poki platform.
Comment[zh_CN]=$name 是Poki平台提供的一款在线小型游戏.
Exec=/opt/apps/$package/files/AppRun %U
Icon=$package
Type=Application
Categories=Games;
StartupWMClass=$package

Terminal=false
StartupNotify=true
EOF
}

### AppRun
{
    cat <<EOF >$deb_app_dir/files/AppRun
#!/bin/bash

cd /opt/apps/$package/files/$package
exec /opt/apps/com.electron.lts/files/Electron/electron ./resources/app.asar "\$@"
EOF
}

    chmod +x $deb_app_dir/files/AppRun

## deb Packing
{
    debuild -b -us -uc -tc

if [ ${ARCH} == "x86_64" ]; then
    arch="amd64"
elif [ ${ARCH} == "aarch64" ]; then
    arch="arm64"
fi

    mv $APP_DIR/deb-build-pool/"$package"_"$VERSION"_"$arch".deb\
 $APP_DIR/bins/
}

## Linyaps packing

### Init linyaps build dir
{
    APP_DIR="$BUILD_DIR/build-pool/$package"
    ll_build_dir="$APP_DIR/ll-build-pool"
    mkdir -p $ll_build_dir/binary $ll_build_dir/template_app/applications
}

### Extract pre-build res
{
    tar -I zstd -xvf $APP_DIR/bins/app-binary-$ARCH.tar.zst\
 -C $ll_build_dir/binary/
    cp -r $deb_app_dir/entries/icons $ll_build_dir/template_app/
}

### Generate linglong.yaml from templates
## Envs for linglong.yaml
    export comment="$name is an online mini-game provided by the Poki platform."
    export prefix="\$PREFIX"
    export PACKAGE=$package.linyaps
    export package=$package
    export name=$name
    export LL_VERSION=$LL_VERSION

## Different runtime version according to the arch
    if [ ${ARCH} == "x86_64" ]; then
      export foundation_version="23.0.0"
    elif [ ${ARCH} == "aarch64" ]; then
      export foundation_version="20.0.0"
    fi

{
    cat "$BUILD_DIR/templates/linglong.yaml" | envsubst >"$ll_build_dir/linglong.yaml"
    cat "$BUILD_DIR/templates/ll.desktop" | envsubst >"$ll_build_dir/template_app/applications/$PACKAGE.desktop"
}

## Tar linyaps build dir
    pushd "$APP_DIR"
    tar -caf $package-ll_build-$ARCH.tar.zst ./ll-build-pool
    rm -rf $ll_build_dir $npm_build_dir $deb_build_dir

done < "$1"