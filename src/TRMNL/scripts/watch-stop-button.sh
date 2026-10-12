#!/bin/sh

# Drop $1 when the home button is pressed, so the loop can stop without the
# hold-power reboot. Drop $2, when given, on a short tap of the power button,
# which wakes the device: the loop reads it as "show me the current dashboard now".
#
# NOTE: Nickel grabs the input device exclusively, so this sees nothing until
#       trmnl.sh has killed it. That is the normal case here.
# NOTE: The home button shares its node with the power button, which is how the
#       device is woken, so the key code matters: reacting to any key would stop
#       the loop on every wake.

FLAG=${1:-/tmp/trmnl_stop}
TAP_FLAG=${2:-}
KEY_HOME=102
KEY_POWER=116
# A tap to wake is comfortably under this; a deliberate hold to exit is
# comfortably over it, well short of the firmware's own hold-to-power-off.
POWER_HOLD_MS=1500

# input_scan prints its matches as CSV, take the first
device=$(./bin/fbink/input_scan -q -p -m home -x touchscreen 2>/dev/null | cut -d, -f1)
if [ -n "$device" ] && [ -e "$device" ]; then
    if [ -n "$TAP_FLAG" ]; then
        # Power is a different key, so a home button device needs a second
        # reader, for taps only ("-": a power hold does nothing here, the
        # firmware owns that). Readers do not exclude each other.
        power_device=$(./bin/fbink/input_scan -q -p -m power -x touchscreen 2>/dev/null | cut -d, -f1)
        if [ -n "$power_device" ] && [ -e "$power_device" ]; then
            ./scripts/log.sh "Watching ${power_device} for power button taps" "DEBUG"
            ./bin/luajit lua/watch_key.lua "$power_device" "$KEY_POWER" - "$POWER_HOLD_MS" "$TAP_FLAG" &
        fi
    fi
    ./scripts/log.sh "Watching ${device} for the home button" "DEBUG"
    exec ./bin/luajit lua/watch_key.lua "$device" "$KEY_HOME" "$FLAG"
fi

# No dedicated home button (e.g. Clara HD): fall back to the power button,
# which every scheduled wake also presses, so a plain press can't mean stop.
# Holding it does, since a scheduled wake never holds it.
device=$(./bin/fbink/input_scan -q -p -m power -x touchscreen 2>/dev/null | cut -d, -f1)
if [ -z "$device" ] || [ ! -e "$device" ]; then
    ./scripts/log.sh "No home or power button found, the loop cannot be stopped by a button" "WARN"
    exit 0
fi

./scripts/log.sh "No home button, watching ${device} for a ${POWER_HOLD_MS}ms power button hold" "DEBUG"
exec ./bin/luajit lua/watch_key.lua "$device" "$KEY_POWER" "$FLAG" "$POWER_HOLD_MS" "$TAP_FLAG"
