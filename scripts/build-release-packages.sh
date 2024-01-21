#!/bin/bash

if [ ! -z ${LHELPER_ENV_NAME+x} ]; then
  echo "error: the script should not be used from an activated environment."
  exit 1
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  export MACOSX_DEPLOYMENT_TARGET="10.11"
  python3 -m venv .env
  source .env/bin/activate
  pip install dmgbuild
fi

rm -fr .lhelper
# We have the build-wayland environment for Wayland builds
lhelper create build
source "$(lhelper env-source build)"

if [[ "$OSTYPE" == "msys" ]]; then
  bash scripts/build.sh --portable --release --system-lua --pgo
  bash scripts/package.sh --binary --release
  bash scripts/package.sh --addons --binary --release
elif [[ "$OSTYPE" == "linux"* || "$OSTYPE" == "freebsd"* ]]; then
  bash scripts/build.sh --portable --release --system-lua --pgo
  bash scripts/package.sh --binary --release
  bash scripts/package.sh --addons --binary --release

  # We may add the --pgo option, only in the first line below.
  # No needed for the second line since it doesn't do a rebuild.
  bash scripts/appimage.sh --system-lua --pgo --release
  bash scripts/appimage.sh --nobuild --addons
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # We may use the option --pgo below but it doesn't work to run
  # the binary from the build directory when the bundle option
  # is activated.
  # We can use --notarize below to with the package script.
  bash scripts/build.sh --bundle --release --system-lua
  bash scripts/package.sh --dmg --release --notarize
  bash scripts/package.sh --addons --dmg --release --notarize
fi

