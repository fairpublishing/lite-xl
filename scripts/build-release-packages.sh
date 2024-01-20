#!/bin/bash

rm -fr .lhelper
lhelper create build
source "$(lhelper env-source build)"

bash scripts/build.sh --portable --release --system-lua --pgo
bash scripts/package.sh --binary --release
bash scripts/package.sh --addons --binary --release

# We may add the --pgo option, only in the first line below.
# No needed for the second line since it doesn't do a rebuild.
bash scripts/appimage.sh --system-lua --pgo --release
bash scripts/appimage.sh --nobuild --addons

