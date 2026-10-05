#!/usr/bin/env bash
# Build the .iq store package - every supported device in one bundle.
#
# This is what the Connect IQ store upload form wants; a .prg is the
# single-device sideload artefact and the form will reject it.
#
#   -e  package the app (.iq) instead of a device .prg
#   -r  strip debug info (release)
#
# Run buildall.sh first: -e builds every product in the manifest, and a
# device that fails there will fail here too, just less legibly.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CIQ_HOME="$APPDATA/Garmin/ConnectIQ"
SDK_W="$(tr -d '\r\n' < "$CIQ_HOME/current-sdk.cfg")"
BS="$(printf '\x5c')"; SDK_W="${SDK_W%"$BS"}"
SDK_DIR="$(cygpath -u "$SDK_W")"
KEY_W='C:\Users\born\Projects\Garmin\keys\developer_key.der'
OUT="$HERE/bin/Everdo.iq"
mkdir -p "$HERE/bin"

java -jar "$(cygpath -w "$SDK_DIR/bin/monkeybrains.jar")" \
    -e -r -w -l 3 \
    -f "$(cygpath -w "$HERE/monkey.jungle")" \
    -o "$(cygpath -w "$OUT")" \
    -y "$KEY_W"
echo "built $(ls -lh "$OUT" | awk '{print $5}') -> bin/Everdo.iq"
