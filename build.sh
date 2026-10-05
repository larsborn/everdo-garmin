#!/usr/bin/env bash
# Build Everdo and optionally run it in the Connect IQ simulator.
# Works from Git Bash and from WSL (uses the Windows JDK/SDK through interop).
#   ./build.sh             -> build for venux1
#   ./build.sh venu3       -> build for venu3
#   ./build.sh venux1 run  -> build and launch in simulator
set -euo pipefail
DEVICE="${1:-venux1}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL: Windows env vars are not inherited, ask cmd.exe for them.
    APPDATA_W="$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')"
    CIQ_HOME="$(wslpath -u "$APPDATA_W")/Garmin/ConnectIQ"
    JAVA=java.exe
    towin() { wslpath -w "$1"; }
    tounix() { wslpath -u "$1"; }
    runbat() { cmd.exe /c "$@"; }
else
    CIQ_HOME="$APPDATA/Garmin/ConnectIQ"
    JAVA=java
    towin() { cygpath -w "$1"; }
    tounix() { cygpath -u "$1"; }
    runbat() { "$@"; }
fi

SDK_W="$(tr -d '\r\n' < "$CIQ_HOME/current-sdk.cfg" 2>/dev/null || true)"
BS="$(printf '\x5c')"           # a literal backslash, kept out of the source text
SDK_W="${SDK_W%"$BS"}"          # strip trailing backslash
[ -n "$SDK_W" ] || { echo "No active SDK in $CIQ_HOME/current-sdk.cfg - run the SDK Manager first." >&2; exit 1; }
SDK_DIR="$(tounix "$SDK_W")"
[ -d "$SDK_DIR/bin" ] || { echo "SDK dir not found: $SDK_DIR" >&2; exit 1; }

# Real path of the key (P: is a subst drive and is not visible from WSL).
KEY_W='C:\Users\born\Projects\Garmin\keys\developer_key.der'
mkdir -p "$HERE/bin"
OUT="$HERE/bin/Everdo.prg"

"$JAVA" -jar "$(towin "$SDK_DIR/bin/monkeybrains.jar")" \
    -d "$DEVICE" -f "$(towin "$HERE/monkey.jungle")" -o "$(towin "$OUT")" -y "$KEY_W" -w -l 3
echo "built bin/Everdo.prg for $DEVICE"

if [ "${2:-}" = "run" ]; then
    "$SDK_DIR/bin/simulator.exe" >/dev/null 2>&1 &
    sleep 3
    runbat "$(towin "$SDK_DIR/bin/monkeydo.bat")" "$(towin "$OUT")" "$DEVICE"
fi
