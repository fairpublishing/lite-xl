#!/bin/bash

if [ ! -z ${LHELPER_ENV_NAME+x} ]; then
  echo "error: the script should not be used from an activated environment."
  exit 1
fi

source scripts/common.sh

if [[ "$OSTYPE" == "darwin"* ]]; then
    MACOSX_DEPLOYMENT_TARGET="10.11"
    if [[ "$(uname -m)" == "arm64" ]]; then
        MACOSX_DEPLOYMENT_TARGET="11.0"
    fi
    export MACOSX_DEPLOYMENT_TARGET
fi

unset VERSION
extract_version VERSION meson.build
if [ -z ${VERSION+x} ]; then
  echo "error: cannot find the version from file meson.build"
  exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  rm -fr .env
  python3 -m venv .env
  source .env/bin/activate
  pip install dmgbuild
  # ask to the user if he wants to notarize the application.
  # if yes set the notarize variable to "--notarize".
  read -p "Do you want to notarize the application? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    notarize="--notarize"
  else
    unset notarize
  fi
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  read -p "Enter CPU target architecture (arm64/x86-64): " ARCH
  if [[ "$ARCH" == "x86-64" ]]; then
    export CMAKE_OSX_ARCHITECTURES="x86_64" CPU_TYPE="x86-64" CPU_TARGET="x86-64" \
    CC="gcc -arch x86_64" CXX="g++ -arch x86_64" \
    OBJC="gcc -arch x86_64" OBJCXX="g++ -arch x86_64"
  elif [[ "$ARCH" == "arm64" ]]; then
    export CMAKE_OSX_ARCHITECTURES="arm64" CPU_TYPE="arm64" CPU_TARGET="arm64" \
    CC="gcc -arch arm64" CXX="g++ -arch arm64" \
    OBJC="gcc -arch arm64" OBJCXX="g++ -arch arm64"
  else
    echo "Invalid architecture. Please enter either arm64 or x86-64."
    exit 1
  fi
  export MACOSX_DEPLOYMENT_TARGET="10.11"
  if [[ "$ARCH" == "arm64" ]]; then
      MACOSX_DEPLOYMENT_TARGET="11.0"
  fi
  CFLAGS="${CFLAGS:+$CFLAGS }-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
  CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
  LDFLAGS="${LDFLAGS:+$LDFLAGS }-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}"
fi

rm -fr .lhelper
# We have the build-wayland environment for Wayland builds
lhelper create build
source "$(lhelper env-source build)"

if [[ "$OSTYPE" == "msys" ]]; then
  bash scripts/build.sh --portable --release --system-lua --pgo
  bash scripts/package.sh --version "$VERSION" --binary --release
  bash scripts/package.sh --version "$VERSION" --addons --binary --release
elif [[ "$OSTYPE" == "linux"* || "$OSTYPE" == "freebsd"* ]]; then
  bash scripts/build.sh --portable --release --system-lua --pgo
  bash scripts/package.sh --version "$VERSION" --binary --release
  bash scripts/package.sh --version "$VERSION" --addons --binary --release

  # We may add the --pgo option, only in the first line below.
  # No needed for the second line since it doesn't do a rebuild.
  bash scripts/appimage.sh --version "$VERSION" --system-lua --pgo --release
  bash scripts/appimage.sh --version "$VERSION" --nobuild --addons
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # We may use the option --pgo below but it doesn't work to run
  # the binary from the build directory when the bundle option
  # is activated.
  # We can use --notarize below to with the package script.
  bash scripts/build.sh --bundle --release --system-lua --arch $ARCH
  bash scripts/package.sh --version "$VERSION" --dmg --release --arch $ARCH $notarize
  bash scripts/package.sh --version "$VERSION" --addons --dmg --release --arch $ARCH $notarize
fi

