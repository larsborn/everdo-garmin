#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1
CIQ_HOME="$APPDATA/Garmin/ConnectIQ"
SDK_W="$(tr -d '\r\n' < "$CIQ_HOME/current-sdk.cfg")"; BS="$(printf '\x5c')"; SDK_W="${SDK_W%"$BS"}"
SDK_DIR="$(cygpath -u "$SDK_W")"
KEY_W="$(cygpath -w "$(cd "$(dirname "$0")/../keys" && pwd)/developer_key.der")"
mkdir -p bin/all
pass=0; fail=0
for d in $(python -c "import json;print(' '.join(x['id'] for x in json.load(open('.devices.json'))))"); do
  out=$(java -jar "$(cygpath -w "$SDK_DIR/bin/monkeybrains.jar")" -d "$d" \
        -f "$(cygpath -w "$PWD/monkey.jungle")" -o "$(cygpath -w "$PWD/bin/all/$d.prg")" \
        -y "$KEY_W" -w -l 3 2>&1)
  if echo "$out" | grep -q "BUILD SUCCESSFUL"; then
    w=$(echo "$out" | grep -c "WARNING")
    pass=$((pass+1)); echo "OK   $d  warnings=$w"
    echo "$out" | grep "WARNING" | sed "s/^/       /"
  else
    fail=$((fail+1)); echo "FAIL $d"; echo "$out" | grep -E "ERROR" | head -3 | sed "s/^/       /"
  fi
done
echo "=== pass=$pass fail=$fail ==="
