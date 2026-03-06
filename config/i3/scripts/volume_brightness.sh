#!/bin/bash
# Brightness script with Gruvbox Dark Blue progress bars

# Gruvbox Dark colors - dark blue progress bar
bar_color="#458588" # Gruvbox dark blue for progress bar fill
volume_step=1
brightness_step=5
max_volume=100

# Detect which brightness control method is available
if command -v brightnessctl >/dev/null 2>&1; then
  brightness_method="brightnessctl"
elif command -v light >/dev/null 2>&1; then
  brightness_method="light"
elif command -v xbacklight >/dev/null 2>&1; then
  brightness_method="xbacklight"
else
  brightness_method="sys"
fi

# Uses regex to get volume from pactl
function get_volume {
  pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}

# Uses regex to get mute status from pactl
function get_mute {
  pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
}

# Get brightness using the available method
function get_brightness {
  case $brightness_method in
  "brightnessctl")
    brightnessctl -m | cut -d',' -f4 | tr -d '%'
    ;;
  "light")
    light | cut -d'.' -f1
    ;;
  "xbacklight")
    xbacklight | grep -Po '[0-9]{1,3}' | head -n 1
    ;;
  "sys")
    if [ -d "/sys/class/backlight" ]; then
      brightness_device=$(ls /sys/class/backlight/ | head -n1)
      if [ -n "$brightness_device" ]; then
        current=$(cat /sys/class/backlight/$brightness_device/brightness 2>/dev/null || echo "0")
        max_brightness=$(cat /sys/class/backlight/$brightness_device/max_brightness 2>/dev/null || echo "100")
        echo $((current * 100 / max_brightness))
      else
        echo "50"
      fi
    else
      echo "50"
    fi
    ;;
  esac
}

# Increase brightness
function brightness_up {
  case $brightness_method in
  "brightnessctl")
    brightnessctl set +${brightness_step}%
    ;;
  "light")
    light -A $brightness_step
    ;;
  "xbacklight")
    xbacklight -inc $brightness_step -time 0
    ;;
  "sys")
    if [ -d "/sys/class/backlight" ]; then
      brightness_device=$(ls /sys/class/backlight/ | head -n1)
      if [ -n "$brightness_device" ]; then
        current=$(cat /sys/class/backlight/$brightness_device/brightness 2>/dev/null || echo "0")
        max_brightness=$(cat /sys/class/backlight/$brightness_device/max_brightness 2>/dev/null || echo "100")
        step=$((max_brightness * brightness_step / 100))
        new=$((current + step))
        if [ $new -gt $max_brightness ]; then
          new=$max_brightness
        fi
        echo $new | sudo tee /sys/class/backlight/$brightness_device/brightness >/dev/null 2>&1
      fi
    fi
    ;;
  esac
}

# Decrease brightness
function brightness_down {
  case $brightness_method in
  "brightnessctl")
    brightnessctl set ${brightness_step}%-
    ;;
  "light")
    light -U $brightness_step
    ;;
  "xbacklight")
    xbacklight -dec $brightness_step -time 0
    ;;
  "sys")
    if [ -d "/sys/class/backlight" ]; then
      brightness_device=$(ls /sys/class/backlight/ | head -n1)
      if [ -n "$brightness_device" ]; then
        current=$(cat /sys/class/backlight/$brightness_device/brightness 2>/dev/null || echo "0")
        max_brightness=$(cat /sys/class/backlight/$brightness_device/max_brightness 2>/dev/null || echo "100")
        step=$((max_brightness * brightness_step / 100))
        new=$((current - step))
        if [ $new -lt 0 ]; then
          new=0
        fi
        echo $new | sudo tee /sys/class/backlight/$brightness_device/brightness >/dev/null 2>&1
      fi
    fi
    ;;
  esac
}

# Volume and brightness icons (using Font Awesome or Unicode)
function get_volume_icon {
  volume=$(get_volume)
  mute=$(get_mute)
  if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ]; then
    volume_icon="" # muted
  elif [ "$volume" -lt 50 ]; then
    volume_icon="" # low volume
  else
    volume_icon="" # high volume
  fi
}

function get_brightness_icon {
  brightness_icon="" # sun icon
}

# Dunst notifications with Gruvbox colors
function show_volume_notif {
  volume=$(get_volume)
  get_volume_icon
  dunstify -i audio-volume-high -t 1500 -r 2593 -u normal "$volume_icon Volume: $volume%" \
    -h int:value:$volume -h string:hlcolor:$bar_color \
    -h string:bgcolor:#282828 -h string:fgcolor:#ebdbb2
}

function show_brightness_notif {
  brightness=$(get_brightness)
  get_brightness_icon
  dunstify -i display-brightness -t 1500 -r 2594 -u normal "$brightness_icon Brightness: $brightness%" \
    -h int:value:$brightness -h string:hlcolor:$bar_color \
    -h string:bgcolor:#282828 -h string:fgcolor:#ffffff
}

# Main function
case $1 in
volume_up)
  pactl set-sink-mute @DEFAULT_SINK@ 0
  volume=$(get_volume)
  if [ $(("$volume" + "$volume_step")) -gt $max_volume ]; then
    pactl set-sink-volume @DEFAULT_SINK@ $max_volume%
  else
    pactl set-sink-volume @DEFAULT_SINK@ +$volume_step%
  fi
  show_volume_notif
  ;;
volume_down)
  pactl set-sink-volume @DEFAULT_SINK@ -$volume_step%
  show_volume_notif
  ;;
volume_mute)
  pactl set-sink-mute @DEFAULT_SINK@ toggle
  show_volume_notif
  ;;
brightness_up)
  brightness_up
  show_brightness_notif
  ;;
brightness_down)
  brightness_down
  show_brightness_notif
  ;;
*)
  echo "Usage: $0 {volume_up|volume_down|volume_mute|brightness_up|brightness_down}"
  echo "Current brightness method: $brightness_method"
  exit 1
  ;;
esac
