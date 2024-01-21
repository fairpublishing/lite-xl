#!/bin/bash

if [ ! -z ${LHELPER_ENV_NAME+x} ]; then
  echo "error: the script should not be used from an activated environment."
  exit 1
fi

rm -fr .lhelper
# We have the build-wayland environment for Wayland builds
lhelper create build
source "$(lhelper env-source build)"

bash scripts/build.sh --portable --release --system-lua --pgo
bash scripts/package.sh --binary --release
bash scripts/package.sh --addons --binary --release

# We may add the --pgo option, only in the first line below.
# No needed for the second line since it doesn't do a rebuild.
bash scripts/appimage.sh --system-lua --pgo --release
bash scripts/appimage.sh --nobuild --addons

