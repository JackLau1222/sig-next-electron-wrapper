#!/bin/bash

TOOLS_VERSION="7.2.0"

set -x

SELF=$(readlink -f "$0")
BUILD_DIR=${SELF%/*}
ARCH=$(uname -m)

## Auto read
while IFS=_ read package name homepage icon_url developer; do

## Generated
    APP_DIR="$BUILD_DIR/build-pool/$package"
    mkdir -p $APP_DIR/bins/

## Extract ll_build_dir
    tar -I zstd -xvf $APP_DIR/$package-ll_build-$ARCH.tar.zst\
 -C $APP_DIR/
    ll_build_dir="$APP_DIR/ll-build-pool"

    pushd "$ll_build_dir"

## Build linyaps project
    ll-builder build -v

## Extract binary
    ll-builder export --layer
    mv "$package".linyaps_*_*_binary.layer $APP_DIR/bins/

done < "$1"
