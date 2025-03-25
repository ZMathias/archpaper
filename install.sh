#!/usr/bin/env bash

config_file="$HOME/.config/daily_wallpaper/config.conf"
config_file_dir="$HOME/.config/daily_wallpaper"
resolution_def="UHD"
scalingMode_def="preserveAspectCrop"
index_def="0"


write_default_config() {
    jq -n \
    --arg res "$resolution_def" \
    --arg scale "$scalingMode_def" \
    --arg index "$index_def" \
    '{
"resolution": $res,
"scalingMode": $scale,
"imageIndex": $index
    }' > "$config_file"
}

set_up_scheduling_units() {
    sudo touch /home/mathias/.config/systemd/user/daily_wallpaper.service
    sudo tee /home/mathias/.config/systemd/user/daily_wallpaper.service > /dev/null << EOF
[Unit]
Description=Run daily_wallpaper service to set bing wallpapers automatically.
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=${HOME}/.config/daily_wallpaper/daily_wallpaper.sh
WorkingDirectory=${HOME}/.config/daily_wallpaper
Type=oneshot
EOF
        sudo touch /home/mathias/.config/systemd/user/daily_wallpaper.timer
        sudo tee /home/mathias/.config/systemd/user/daily_wallpaper.timer > /dev/null << 'EOF' # HERE-DOC START
[Unit]
Description=Run daily_wallpaper at boot and at midnight

[Timer]
OnBootSec=1min
OnCalendar=*-*-* 00:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
# HERE-DOC END
        sudo systemctl daemon-reload
        systemctl --user enable --now daily_wallpaper.timer
}

place_script() {
    if [ ! -f "$config_file_dir/daily_wallpaper.sh" ]; then
        # Get the full path of the currently running script
        exec_path="$(readlink -f "$0")"
        if [[ -z "$exec_path" || ! -f "$exec_path" ]]; then
            echo "[ERROR] Couldn't retrieve the script path. Exiting."
            exit 1
        fi

        # Download the file
        curl -fsSL "https://raw.githubusercontent.com/ZMathias/archpaper/refs/heads/main/daily_wallpaper.sh" -o "${config_file_dir}/daily_wallpaper.sh"

        # Make it executable
        chmod +x "${config_file_dir}/daily_wallpaper.sh"
    fi
}

# or creates one with default config parameters if not found
open_config() {
    # look for config file and create it with default values if not found
    if [ -f "$config_file" ]; then
        echo "[INFO] Opening config file at $config_file"
        if [ ! -s "$config_file" ]; then
            echo "[WARN] File is empty. Writing default config..."
            write_default_config
        fi
        # parse the config file
        resolution_def="$(jq -r ".resolution" < "$config_file")"
        scalingMode_def="$(jq -r ".scalingMode" < "$config_file")"
        index_def="$(jq -r ".imageIndex" < "$config_file")"
    else
        # create the config file if it doesnt exist
        echo "[INFO] Creating config file at $config_file"
        mkdir -p "$config_file_dir"
        touch "$config_file"
        write_default_config

    fi
}

open_config
place_script


if [[ -f "$HOME/.config/systemd/user/daily_wallpaper.service" ]]; then
    echo "[INFO] Scheduling units are already set up"
else
    read -p "Do you want me to set the scheduling units automatically? (Y/n): " answer

    if [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]; then
        echo "Setting up scheduling scripts..."
        set_up_scheduling_units
    else
        echo "[INFO] Skipping scheduling setup."
    fi
fi


# send request to bing wallpaper api for an image and extract the image url for download
api_url="$(curl -H "Accept: application/json" "https://bing.biturl.top/?resolution=$resolution_def&format=json&index=$index_def")"
wallpaper_url=$(jq -r ".url" <<< $api_url)

# change wallpaper to black to cycle plasma cache
wget -O "$config_file_dir/cycle.jpg" "https://mcdn.wallpapersafari.com/medium/30/40/WCayJQ.jpg"
plasma-apply-wallpaperimage -f stretch "$config_file_dir/cycle.jpg"

wget -O "$config_file_dir/wallpaper-$index_def.jpg" $wallpaper_url
plasma-apply-wallpaperimage -f preserveAspectCrop "$config_file_dir/wallpaper-$index_def.jpg"

echo "res: $resolution_def"
echo "scale: $scalingMode_def"
