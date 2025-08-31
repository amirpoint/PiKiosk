#!/bin/bash
set -euo pipefail

# ============================================
# Raspberry Pi Multi-Kiosk Setup Script - Portrait Mode (wlr-randr) v2
# ============================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
print_msg() {
    echo -e "${2}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_msg "This script should not be run as root! Run as regular user." "$RED"
   exit 1
fi

print_msg "Starting Raspberry Pi Multi-Kiosk Setup (Portrait Mode v2)..." "$GREEN"

# Update system packages
print_msg "Updating system packages..." "$YELLOW"
sudo apt update
sudo apt upgrade -y

# Install required packages including wlr-randr for display rotation
print_msg "Installing required packages..." "$YELLOW"
sudo apt install -y \
    chromium-browser \
    unclutter \
    xdotool \
    xinit \
    x11-xserver-utils \
    lightdm \
    openbox \
    obconf \
    menu \
    wlr-randr

# Create necessary directories
print_msg "Creating directory structure..." "$YELLOW"
mkdir -p ~/.config/openbox
mkdir -p ~/.config/systemd/user
mkdir -p ~/kiosk/{scripts,env}
mkdir -p ~/.config/chrome-kiosk-{kuma,kibana,grafana}

# Detect display output name for wlr-randr
print_msg "Detecting display output..." "$YELLOW"
DISPLAY_OUTPUT=""
if command -v wlr-randr >/dev/null 2>&1; then
    # Try to get the display output name
    DISPLAY_OUTPUT=$(wlr-randr 2>/dev/null | grep -E "^[A-Z].*\".*\"$" | head -1 | awk '{print $1}' || echo "")
    if [ -n "$DISPLAY_OUTPUT" ]; then
        print_msg "Detected display output: $DISPLAY_OUTPUT" "$GREEN"
        echo "DISPLAY_OUTPUT=$DISPLAY_OUTPUT" > ~/kiosk/env/display.env
    else
        print_msg "Could not detect display output, using default HDMI-A-1" "$YELLOW"
        echo "DISPLAY_OUTPUT=HDMI-A-1" > ~/kiosk/env/display.env
        DISPLAY_OUTPUT="HDMI-A-1"
    fi
else
    print_msg "wlr-randr not available yet, using default HDMI-A-1" "$YELLOW"
    echo "DISPLAY_OUTPUT=HDMI-A-1" > ~/kiosk/env/display.env
    DISPLAY_OUTPUT="HDMI-A-1"
fi

# Set default portrait rotation
print_msg "Setting default portrait rotation..." "$YELLOW"
echo "270" > ~/kiosk/saved_rotation.conf

# Create environment files if they don't exist
print_msg "Creating environment files..." "$YELLOW"

# Create Kuma env file
if [ ! -f ~/kiosk/env/kuma.env ]; then
    cat > ~/kiosk/env/kuma.env << 'EOF'
KIOSK_NAME="Uptime Kuma"
KIOSK_URL="http://uptime.smartx.ir/dashboard"
ROTATION_MODE="270"
EOF
    print_msg "Created kuma.env - Please edit with your URL" "$YELLOW"
fi

# Create Kibana env file
if [ ! -f ~/kiosk/env/kibana.env ]; then
    cat > ~/kiosk/env/kibana.env << 'EOF'
KIOSK_NAME="Kibana"
KIOSK_URL="http://kibana.example.com/dashboard"
ROTATION_MODE="270"
EOF
    print_msg "Created kibana.env - Please edit with your URL" "$YELLOW"
fi

# Create Grafana env file
if [ ! -f ~/kiosk/env/grafana.env ]; then
    cat > ~/kiosk/env/grafana.env << 'EOF'
KIOSK_NAME="Grafana"
KIOSK_URL="http://grafana.example.com/dashboard"
ROTATION_MODE="270"
EOF
    print_msg "Created grafana.env - Please edit with your URL" "$YELLOW"
fi

# Create rotation persistence service
print_msg "Creating rotation persistence service..." "$YELLOW"
cat > ~/.config/systemd/user/kiosk-rotation.service << EOF
[Unit]
Description=Kiosk Display Rotation Persistence
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="DISPLAY=:0"
Environment="WAYLAND_DISPLAY=wayland-0"
Environment="HOME=$HOME"
Environment="USER=$USER"
ExecStart=$HOME/kiosk/scripts/apply-saved-rotation.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

# Create script to apply saved rotation
print_msg "Creating rotation application script..." "$YELLOW"
cat > ~/kiosk/scripts/apply-saved-rotation.sh << 'EOF'
#!/bin/bash

# Apply saved rotation on startup
ROTATION_SAVE_FILE="$HOME/kiosk/saved_rotation.conf"
DISPLAY_ENV_FILE="$HOME/kiosk/env/display.env"
LOG_FILE="$HOME/kiosk/rotation-startup.log"

# Log startup
echo "[$(date)] Starting rotation persistence service..." >> "$LOG_FILE"

# Wait for wlr-randr to be available
timeout=30
while [ $timeout -gt 0 ]; do
    if command -v wlr-randr >/dev/null 2>&1; then
        if wlr-randr --help >/dev/null 2>&1; then
            echo "[$(date)] wlr-randr is ready" >> "$LOG_FILE"
            break
        fi
    fi
    echo "[$(date)] Waiting for wlr-randr... ($timeout seconds left)" >> "$LOG_FILE"
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "[$(date)] ERROR: wlr-randr not ready after 30 seconds" >> "$LOG_FILE"
    exit 1
fi

# Additional wait for display system to be fully ready
echo "[$(date)] Waiting additional 5 seconds for display system..." >> "$LOG_FILE"
sleep 5

# Source display configuration
if [ -f "$DISPLAY_ENV_FILE" ]; then
    source "$DISPLAY_ENV_FILE"
    echo "[$(date)] Loaded display config: DISPLAY_OUTPUT=$DISPLAY_OUTPUT" >> "$LOG_FILE"
else
    DISPLAY_OUTPUT="HDMI-A-1"
    echo "[$(date)] Using default display: $DISPLAY_OUTPUT" >> "$LOG_FILE"
fi

# Load saved rotation or use default
if [ -f "$ROTATION_SAVE_FILE" ]; then
    SAVED_ROTATION=$(cat "$ROTATION_SAVE_FILE")
    echo "[$(date)] Found saved rotation: $SAVED_ROTATION" >> "$LOG_FILE"
else
    SAVED_ROTATION="270"
    echo "$SAVED_ROTATION" > "$ROTATION_SAVE_FILE"
    echo "[$(date)] No saved rotation found, created default: $SAVED_ROTATION" >> "$LOG_FILE"
fi

# Check available displays
echo "[$(date)] Checking available displays..." >> "$LOG_FILE"
wlr-randr >> "$LOG_FILE" 2>&1

# Apply the rotation
echo "[$(date)] Applying rotation $SAVED_ROTATION to display $DISPLAY_OUTPUT" >> "$LOG_FILE"

case $SAVED_ROTATION in
    "0"|"normal"|"landscape")
        wlr-randr --output "$DISPLAY_OUTPUT" --transform normal >> "$LOG_FILE" 2>&1
        ;;
    "90"|"portrait-left")
        wlr-randr --output "$DISPLAY_OUTPUT" --transform 90 >> "$LOG_FILE" 2>&1
        ;;
    "180"|"inverted")
        wlr-randr --output "$DISPLAY_OUTPUT" --transform 180 >> "$LOG_FILE" 2>&1
        ;;
    "270"|"portrait"|"portrait-right")
        wlr-randr --output "$DISPLAY_OUTPUT" --transform 270 >> "$LOG_FILE" 2>&1
        ;;
    *)
        echo "[$(date)] ERROR: Unknown rotation: $SAVED_ROTATION, using 270" >> "$LOG_FILE"
        wlr-randr --output "$DISPLAY_OUTPUT" --transform 270 >> "$LOG_FILE" 2>&1
        echo "270" > "$ROTATION_SAVE_FILE"
        ;;
esac

# Verify the rotation was applied
echo "[$(date)] Verifying rotation was applied..." >> "$LOG_FILE"
wlr-randr | grep -E "(Transform|Enabled)" >> "$LOG_FILE" 2>&1

echo "[$(date)] Rotation service completed successfully" >> "$LOG_FILE"
EOF
chmod +x ~/kiosk/scripts/apply-saved-rotation.sh

# Create display rotation utility script
print_msg "Creating display rotation utility..." "$YELLOW"
cat > ~/kiosk/scripts/set-rotation.sh << 'EOF'
#!/bin/bash

# Display rotation utility using wlr-randr with persistence
ROTATION="${1:-270}"
SOURCE_DISPLAY_ENV="${2:-$HOME/kiosk/env/display.env}"
ROTATION_SAVE_FILE="$HOME/kiosk/saved_rotation.conf"

# Source display configuration
if [ -f "$SOURCE_DISPLAY_ENV" ]; then
    source "$SOURCE_DISPLAY_ENV"
else
    DISPLAY_OUTPUT="HDMI-A-1"
fi

# Log rotation change
echo "[$(date)] Setting rotation to $ROTATION for display $DISPLAY_OUTPUT" >> "$HOME/kiosk/rotation.log"

# Apply rotation using wlr-randr
if command -v wlr-randr >/dev/null 2>&1; then
    case $ROTATION in
        "0"|"normal"|"landscape")
            wlr-randr --output "$DISPLAY_OUTPUT" --transform normal
            echo "normal" > "$ROTATION_SAVE_FILE"
            echo "[$(date)] Applied and saved normal (landscape) rotation" >> "$HOME/kiosk/rotation.log"
            ;;
        "90"|"portrait-left")
            wlr-randr --output "$DISPLAY_OUTPUT" --transform 90
            echo "90" > "$ROTATION_SAVE_FILE"
            echo "[$(date)] Applied and saved 90° (portrait-left) rotation" >> "$HOME/kiosk/rotation.log"
            ;;
        "180"|"inverted")
            wlr-randr --output "$DISPLAY_OUTPUT" --transform 180
            echo "180" > "$ROTATION_SAVE_FILE"
            echo "[$(date)] Applied and saved 180° (inverted) rotation" >> "$HOME/kiosk/rotation.log"
            ;;
        "270"|"portrait"|"portrait-right")
            wlr-randr --output "$DISPLAY_OUTPUT" --transform 270
            echo "270" > "$ROTATION_SAVE_FILE"
            echo "[$(date)] Applied and saved 270° (portrait-right) rotation" >> "$HOME/kiosk/rotation.log"
            ;;
        *)
            echo "[$(date)] ERROR: Unknown rotation: $ROTATION" >> "$HOME/kiosk/rotation.log"
            exit 1
            ;;
    esac
else
    echo "[$(date)] ERROR: wlr-randr not available" >> "$HOME/kiosk/rotation.log"
    exit 1
fi

# Small delay to let rotation take effect
sleep 1

echo "Rotation $ROTATION applied and saved for next boot"
EOF
chmod +x ~/kiosk/scripts/set-rotation.sh

# Create the main kiosk launcher script with wlr-randr rotation
print_msg "Creating kiosk launcher script with rotation support..." "$YELLOW"
cat > ~/kiosk/scripts/kiosk-launcher.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Main kiosk launcher script - Portrait Mode with wlr-randr v2
KIOSK_TYPE="${1:-kuma}"
ENV_FILE="$HOME/kiosk/env/${KIOSK_TYPE}.env"
DISPLAY_ENV_FILE="$HOME/kiosk/env/display.env"
PROFILE_DIR="$HOME/.config/chrome-kiosk-${KIOSK_TYPE}"
LOG="$HOME/kiosk/kiosk-${KIOSK_TYPE}.log"

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "[ERROR] Environment file not found: $ENV_FILE" >> "$LOG"
    exit 1
fi

# Source the environment files
source "$ENV_FILE"
if [ -f "$DISPLAY_ENV_FILE" ]; then
    source "$DISPLAY_ENV_FILE"
else
    DISPLAY_OUTPUT="HDMI-A-1"
fi

# Create profile directory if it doesn't exist
mkdir -p "$PROFILE_DIR"

# Log startup
echo "[$(date)] Starting ${KIOSK_NAME} kiosk with rotation ${ROTATION_MODE:-270}..." >> "$LOG"

# Wait for system to be ready
sleep 5

# Set display rotation using wlr-randr
echo "[$(date)] Setting display rotation..." >> "$LOG"
if [ -n "${ROTATION_MODE:-}" ]; then
    "$HOME/kiosk/scripts/set-rotation.sh" "$ROTATION_MODE" >> "$LOG" 2>&1 || {
        echo "[$(date)] WARNING: Failed to set rotation, continuing..." >> "$LOG"
    }
fi

# Wait for network connectivity
echo "[$(date)] Waiting for network..." >> "$LOG"
timeout=60
while [ $timeout -gt 0 ]; do
    if ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
        echo "[$(date)] Network connected" >> "$LOG"
        break
    fi
    sleep 2
    timeout=$((timeout - 2))
done

if [ $timeout -le 0 ]; then
    echo "[$(date)] WARNING: Network not ready after 60 seconds, continuing anyway" >> "$LOG"
fi

# Kill any existing chromium instances
pkill -x chromium-browser >/dev/null 2>&1 || true
sleep 2

# Configure display settings
if command -v xset >/dev/null 2>&1; then
    # Disable screen blanking
    xset s off 2>/dev/null || true
    xset -dpms 2>/dev/null || true
    xset s noblank 2>/dev/null || true
fi

# Hide mouse cursor after 3 seconds of inactivity
if command -v unclutter >/dev/null 2>&1; then
    unclutter -idle 3 &
fi

# Launch Chromium in kiosk mode
echo "[$(date)] Launching Chromium for ${KIOSK_NAME} (Rotation: ${ROTATION_MODE:-270})..." >> "$LOG"
echo "[$(date)] URL: $KIOSK_URL" >> "$LOG"

export DISPLAY=${DISPLAY:-:0}
export XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}

chromium-browser \
    --kiosk \
    --noerrdialogs \
    --disable-session-crashed-bubble \
    --disable-infobars \
    --no-first-run \
    --no-default-browser-check \
    --disable-translate \
    --disable-features=TranslateUI \
    --disable-component-update \
    --autoplay-policy=no-user-gesture-required \
    --user-data-dir="$PROFILE_DIR" \
    --disable-web-security \
    --disable-features=VizDisplayCompositor \
    --start-maximized \
    --force-device-scale-factor=1.0 \
    "$KIOSK_URL" >> "$LOG" 2>&1
EOF
chmod +x ~/kiosk/scripts/kiosk-launcher.sh

# Create kiosk switcher script with rotation support
print_msg "Creating kiosk switcher script..." "$YELLOW"
cat > ~/kiosk/scripts/switch-kiosk.sh << 'EOF'
#!/bin/bash

# Kiosk switcher script with rotation support v2
# Usage: ./switch-kiosk.sh [kuma|kibana|grafana] [rotation]

KIOSK_TYPE="${1:-kuma}"
NEW_ROTATION="${2:-}"

# Valid kiosk types
VALID_TYPES=("kuma" "kibana" "grafana")

# Check if the provided type is valid
if [[ ! " ${VALID_TYPES[@]} " =~ " ${KIOSK_TYPE} " ]]; then
    echo "Error: Invalid kiosk type. Valid options are: ${VALID_TYPES[*]}"
    exit 1
fi

echo "Switching to ${KIOSK_TYPE} kiosk..."

# Update rotation if specified
if [ -n "$NEW_ROTATION" ]; then
    ENV_FILE="$HOME/kiosk/env/${KIOSK_TYPE}.env"
    if [ -f "$ENV_FILE" ]; then
        # Update rotation in environment file
        sed -i "s/^ROTATION_MODE=.*/ROTATION_MODE=\"$NEW_ROTATION\"/" "$ENV_FILE"
        echo "Updated rotation to $NEW_ROTATION for $KIOSK_TYPE"
        
        # Also save as system default
        echo "$NEW_ROTATION" > "$HOME/kiosk/saved_rotation.conf"
    fi
fi

# Stop all kiosk services
for type in "${VALID_TYPES[@]}"; do
    systemctl --user stop "kiosk-${type}.service" 2>/dev/null || true
    systemctl --user disable "kiosk-${type}.service" 2>/dev/null || true
done

# Enable and start the selected kiosk
systemctl --user enable "kiosk-${KIOSK_TYPE}.service"
systemctl --user start "kiosk-${KIOSK_TYPE}.service"

echo "Switched to ${KIOSK_TYPE} kiosk successfully!"
echo "You can check the status with: systemctl --user status kiosk-${KIOSK_TYPE}.service"
EOF
chmod +x ~/kiosk/scripts/switch-kiosk.sh

# Create set-default-rotation script
print_msg "Creating default rotation setter..." "$YELLOW"
cat > ~/kiosk/scripts/set-default-rotation.sh << 'EOF'
#!/bin/bash

# Set default rotation for the system
ROTATION="${1:-270}"

echo "Setting default rotation to: $ROTATION"

# Save the rotation
echo "$ROTATION" > "$HOME/kiosk/saved_rotation.conf"

# Apply it immediately
"$HOME/kiosk/scripts/set-rotation.sh" "$ROTATION"

# Enable the rotation persistence service
systemctl --user enable kiosk-rotation.service
systemctl --user start kiosk-rotation.service

echo "Default rotation set to $ROTATION and will persist after reboot"
EOF
chmod +x ~/kiosk/scripts/set-default-rotation.sh

# Create systemd service files for each kiosk type
print_msg "Creating systemd service files..." "$YELLOW"

for kiosk_type in kuma kibana grafana; do
    cat > ~/.config/systemd/user/kiosk-${kiosk_type}.service << EOF
[Unit]
Description=Kiosk Mode - ${kiosk_type^} (Portrait v2)
After=graphical-session.target network-online.target kiosk-rotation.service
Wants=network-online.target kiosk-rotation.service

[Service]
Type=simple
Restart=always
RestartSec=10
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME/.Xauthority"
Environment="WAYLAND_DISPLAY=wayland-0"
ExecStart=$HOME/kiosk/scripts/kiosk-launcher.sh ${kiosk_type}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
done

# Create OpenBox autostart configuration
print_msg "Configuring OpenBox autostart..." "$YELLOW"
cat > ~/.config/openbox/autostart << 'EOF'
# OpenBox Autostart Configuration - Portrait Mode v2
# Disable screen saver
xset s off &
xset -dpms &
xset s noblank &

# Remove mouse cursor after 3 seconds
unclutter -idle 3 &

# Apply saved rotation early (backup method)
(
  sleep 3
  if [ -f "$HOME/kiosk/scripts/apply-saved-rotation.sh" ]; then
    "$HOME/kiosk/scripts/apply-saved-rotation.sh" &
  fi
) &
EOF

# Configure auto-login for current user
print_msg "Configuring auto-login..." "$YELLOW"
sudo mkdir -p /etc/lightdm/lightdm.conf.d/
sudo tee /etc/lightdm/lightdm.conf.d/10-autologin.conf > /dev/null << EOF
[Seat:*]
autologin-user=$USER
autologin-user-timeout=0
user-session=openbox
EOF

# Configure boot behavior
print_msg "Configuring boot behavior..." "$YELLOW"

# Disable screen blanking in console
if ! grep -q "consoleblank=0" /boot/cmdline.txt 2>/dev/null; then
    sudo sed -i 's/$/ consoleblank=0/' /boot/cmdline.txt 2>/dev/null || true
fi

# Hide boot messages
if ! grep -q "logo.nologo" /boot/cmdline.txt 2>/dev/null; then
    sudo sed -i 's/$/ logo.nologo quiet splash loglevel=0/' /boot/cmdline.txt 2>/dev/null || true
fi

# Create helper scripts
print_msg "Creating helper scripts..." "$YELLOW"

# Create status checker script
cat > ~/kiosk/scripts/check-status.sh << 'EOF'
#!/bin/bash
echo "=== Portrait Mode Kiosk Services Status (v2) ==="
for service in kuma kibana grafana; do
    status=$(systemctl --user is-active kiosk-${service}.service 2>/dev/null || echo "inactive")
    if [ "$status" = "active" ]; then
        echo -e "\033[0;32m● kiosk-${service}: ${status}\033[0m"
    else
        echo -e "\033[0;90m○ kiosk-${service}: ${status}\033[0m"
    fi
done

echo ""
echo "=== Rotation Service Status ==="
rot_status=$(systemctl --user is-active kiosk-rotation.service 2>/dev/null || echo "inactive")
if [ "$rot_status" = "active" ]; then
    echo -e "\033[0;32m● kiosk-rotation: ${rot_status}\033[0m"
else
    echo -e "\033[0;31m○ kiosk-rotation: ${rot_status}\033[0m"
fi

echo ""
echo "=== Display Information ==="
if command -v wlr-randr >/dev/null 2>&1; then
    echo "Current display settings:"
    wlr-randr 2>/dev/null | grep -E "(^[A-Z]|Transform:|Enabled:)" || echo "No display info available"
    echo ""
    if [ -f "$HOME/kiosk/saved_rotation.conf" ]; then
        saved_rot=$(cat "$HOME/kiosk/saved_rotation.conf")
        echo "Saved rotation for next boot: $saved_rot"
    fi
else
    echo "wlr-randr not available"
fi
EOF
chmod +x ~/kiosk/scripts/check-status.sh

# Create logs viewer script
cat > ~/kiosk/scripts/view-logs.sh << 'EOF'
#!/bin/bash
KIOSK_TYPE="${1:-kuma}"
echo "=== Showing logs for ${KIOSK_TYPE} kiosk (Portrait v2) ==="
journalctl --user -u kiosk-${KIOSK_TYPE}.service -f
EOF
chmod +x ~/kiosk/scripts/view-logs.sh

# Create rotation toggle script using wlr-randr
cat > ~/kiosk/scripts/toggle-rotation.sh << 'EOF'
#!/bin/bash

# Toggle display rotation script using wlr-randr v2
# Usage: ./toggle-rotation.sh [normal|90|180|270|portrait|landscape]

ROTATION="${1:-270}"
DISPLAY_ENV_FILE="$HOME/kiosk/env/display.env"

# Source display configuration
if [ -f "$DISPLAY_ENV_FILE" ]; then
    source "$DISPLAY_ENV_FILE"
else
    DISPLAY_OUTPUT="HDMI-A-1"
fi

echo "Setting display rotation to: $ROTATION on $DISPLAY_OUTPUT"

# Apply rotation
"$HOME/kiosk/scripts/set-rotation.sh" "$ROTATION"

# Update all kiosk environment files with new rotation
for env_file in "$HOME"/kiosk/env/{kuma,kibana,grafana}.env; do
    if [ -f "$env_file" ]; then
        sed -i "s/^ROTATION_MODE=.*/ROTATION_MODE=\"$ROTATION\"/" "$env_file"
    fi
done

# Restart active kiosk service to apply rotation
for service in kuma kibana grafana; do
    if systemctl --user is-active --quiet kiosk-${service}.service; then
        echo "Restarting ${service} kiosk service to apply rotation..."
        systemctl --user restart kiosk-${service}.service
        break
    fi
done

echo "Rotation applied successfully!"
EOF
chmod +x ~/kiosk/scripts/toggle-rotation.sh

# Create enhanced manager script
cat > ~/kiosk/scripts/manager.sh << 'MANAGER_EOF'
#!/bin/bash

# ============================================
# Kiosk Manager - Interactive Management Tool (Portrait v2)
# ============================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display header
show_header() {
    clear
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  Raspberry Pi Kiosk Manager (Portrait v2) ${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

# Function to get active kiosk
get_active_kiosk() {
    for service in kuma kibana grafana; do
        if systemctl --user is-active --quiet kiosk-${service}.service; then
            echo "$service"
            return
        fi
    done
    echo "none"
}

# Function to get current rotation
get_current_rotation() {
    if command -v wlr-randr >/dev/null 2>&1; then
        transform=$(wlr-randr 2>/dev/null | grep "Transform:" | head -1 | awk '{print $2}' || echo "unknown")
        case $transform in
            "normal") echo "0° (Landscape)" ;;
            "90") echo "90° (Portrait Left)" ;;
            "180") echo "180° (Inverted)" ;;
            "270") echo "270° (Portrait Right)" ;;
            *) echo "Unknown ($transform)" ;;
        esac
    else
        echo "wlr-randr not available"
    fi
}

# Function to get saved rotation
get_saved_rotation() {
    if [ -f "$HOME/kiosk/saved_rotation.conf" ]; then
        saved_rot=$(cat "$HOME/kiosk/saved_rotation.conf")
        case $saved_rot in
            "normal"|"0") echo "0° (Landscape) - SAVED" ;;
            "90") echo "90° (Portrait Left) - SAVED" ;;
            "180") echo "180° (Inverted) - SAVED" ;;
            "270") echo "270° (Portrait Right) - SAVED" ;;
            *) echo "$saved_rot - SAVED" ;;
        esac
    else
        echo "No saved rotation (will use 270° default)"
    fi
}

# Function to show status
show_status() {
    show_header
    echo -e "${YELLOW}Current Status:${NC}"
    echo ""
    
    active_kiosk=$(get_active_kiosk)
    
    for service in kuma kibana grafana; do
        # Load environment to get the name
        if [ -f "$HOME/kiosk/env/${service}.env" ]; then
            source "$HOME/kiosk/env/${service}.env"
            name="$KIOSK_NAME"
            rotation="${ROTATION_MODE:-270}"
        else
            name="${service^}"
            rotation="270"
        fi
        
        status=$(systemctl --user is-active kiosk-${service}.service 2>/dev/null || echo "inactive")
        
        if [ "$status" = "active" ]; then
            echo -e "  ${GREEN}● ${name}: ACTIVE (Rotation: ${rotation})${NC}"
        else
            echo -e "  ${RED}○ ${name}: ${status}${NC}"
        fi
    done
    
    # Rotation service status
    echo ""
    echo -e "${YELLOW}Rotation Service:${NC}"
    rot_status=$(systemctl --user is-active kiosk-rotation.service 2>/dev/null || echo "inactive")
    if [ "$rot_status" = "active" ]; then
        echo -e "  ${GREEN}● Rotation Service: ${rot_status}${NC}"
    else
        echo -e "  ${RED}○ Rotation Service: ${rot_status}${NC}"
    fi
    
    # Display info
    echo ""
    echo -e "${YELLOW}Display Info:${NC}"
    current_rotation=$(get_current_rotation)
    saved_rotation=$(get_saved_rotation)
    echo -e "  Current rotation: ${CYAN}${current_rotation}${NC}"
    echo -e "  Saved for reboot: ${CYAN}${saved_rotation}${NC}"
    
    if command -v wlr-randr >/dev/null 2>&1; then
        display_output=$(wlr-randr 2>/dev/null | grep -E "^[A-Z].*\".*\"$" | head -1 | awk '{print $1}' || echo "Unknown")
        echo -e "  Display output: ${CYAN}${display_output}${NC}"
    fi
    echo ""
}

# Function to switch kiosk
switch_kiosk() {
    local new_kiosk=$1
    
    echo -e "${YELLOW}Switching to ${new_kiosk} kiosk...${NC}"
    
    # Stop all services
    for service in kuma kibana grafana; do
        systemctl --user stop kiosk-${service}.service 2>/dev/null || true
        systemctl --user disable kiosk-${service}.service 2>/dev/null || true
    done
    
    # Start selected service
    systemctl --user enable kiosk-${new_kiosk}.service
    systemctl --user start kiosk-${new_kiosk}.service
    
    sleep 2
    
    if systemctl --user is-active --quiet kiosk-${new_kiosk}.service; then
        echo -e "${GREEN}✓ Successfully switched to ${new_kiosk}${NC}"
    else
        echo -e "${RED}✗ Failed to start ${new_kiosk}${NC}"
        echo "Check logs with: journalctl --user -u kiosk-${new_kiosk}.service"
    fi
}

# Function to restart kiosk
restart_kiosk() {
    local active_kiosk=$(get_active_kiosk)
    
    if [ "$active_kiosk" = "none" ]; then
        echo -e "${RED}No active kiosk to restart!${NC}"
        return
    fi
    
    echo -e "${YELLOW}Restarting ${active_kiosk} kiosk...${NC}"
    systemctl --user restart kiosk-${active_kiosk}.service
    
    sleep 2
    
    if systemctl --user is-active --quiet kiosk-${active_kiosk}.service; then
        echo -e "${GREEN}✓ Successfully restarted ${active_kiosk}${NC}"
    else
        echo -e "${RED}✗ Failed to restart ${active_kiosk}${NC}"
    fi
}

# Function to stop all kiosks
stop_all() {
    echo -e "${YELLOW}Stopping all kiosk services...${NC}"
    
    for service in kuma kibana grafana; do
        systemctl --user stop kiosk-${service}.service 2>/dev/null || true
    done
    
    echo -e "${GREEN}✓ All services stopped${NC}"
}

# Function to toggle rotation using wlr-randr
toggle_rotation() {
    echo -e "${YELLOW}Rotation Options (wlr-randr v2):${NC}"
    echo "  1) Landscape (normal) - 0°"
    echo "  2) Portrait Left - 90°"
    echo "  3) Inverted - 180°"
    echo "  4) Portrait Right - 270° (recommended)"
    echo ""
    
    read -p "Select rotation: " rot_choice
    
    case $rot_choice in
        1) rotation="normal" ;;
        2) rotation="90" ;;
        3) rotation="180" ;;
        4) rotation="270" ;;
        *) 
            echo -e "${RED}Invalid option!${NC}"
            return
            ;;
    esac
    
    echo -e "${YELLOW}Applying $rotation rotation using wlr-randr...${NC}"
    ~/kiosk/scripts/set-default-rotation.sh "$rotation"
    echo -e "${GREEN}✓ Rotation applied and saved${NC}"
}

# Function to show display info
show_display_info() {
    echo -e "${CYAN}=== Display Information (v2) ===${NC}"
    if command -v wlr-randr >/dev/null 2>&1; then
        wlr-randr 2>/dev/null || echo "No display information available"
    else
        echo "wlr-randr not available"
    fi
    echo ""
    echo "Logs available at:"
    echo "  Rotation startup: ~/kiosk/rotation-startup.log"
    echo "  Rotation changes: ~/kiosk/rotation.log"
}

# Main menu
main_menu() {
    while true; do
        show_status
        
        echo -e "${CYAN}Options:${NC}"
        echo "  1) Switch to Kuma Kiosk"
        echo "  2) Switch to Kibana Kiosk"
        echo "  3) Switch to Grafana Kiosk"
        echo "  4) Stop All Kiosks"
        echo "  5) Restart Active Kiosk"
        echo "  6) Change Display Rotation"
        echo "  7) Show Display Info"
        echo "  Q) Quit"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1) switch_kiosk "kuma" ;;
            2) switch_kiosk "kibana" ;;
            3) switch_kiosk "grafana" ;;
            4) stop_all ;;
            5) restart_kiosk ;;
            6) toggle_rotation ;;
            7) show_display_info ;;
            [Qq]) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run interactive menu
main_menu
MANAGER_EOF
chmod +x ~/kiosk/scripts/manager.sh

# Reload systemd and enable rotation service
print_msg "Enabling rotation persistence service..." "$YELLOW"
systemctl --user daemon-reload
systemctl --user enable kiosk-rotation.service

# Final setup message
print_msg "===========================================" "$GREEN"
print_msg "Portrait Mode Setup v2 completed!" "$GREEN"
print_msg "===========================================" "$GREEN"
echo ""
echo -e "${CYAN}IMPORTANT: Please edit the environment files in ~/kiosk/env/${NC}"
echo "  - ~/kiosk/env/kuma.env"
echo "  - ~/kiosk/env/kibana.env"
echo "  - ~/kiosk/env/grafana.env"
echo ""
echo -e "${CYAN}Portrait Mode v2 Features:${NC}"
echo "  ✓ Uses wlr-randr for modern display rotation"
echo "  ✓ Persistent rotation after reboot"
echo "  ✓ Rotation service with proper dependencies"
echo "  ✓ Detected display output: $DISPLAY_OUTPUT"
echo "  ✓ Default portrait rotation (270°) configured"
echo ""
echo -e "${CYAN}Available commands:${NC}"
echo "  Interactive Manager:  ~/kiosk/scripts/manager.sh"
echo "  Switch kiosk:        ~/kiosk/scripts/switch-kiosk.sh [kuma|kibana|grafana] [rotation]"
echo "  Set default rotation: ~/kiosk/scripts/set-default-rotation.sh [normal|90|180|270]"
echo "  Toggle rotation:     ~/kiosk/scripts/toggle-rotation.sh [normal|90|180|270]"
echo "  Check status:        ~/kiosk/scripts/check-status.sh"
echo "  View logs:           ~/kiosk/scripts/view-logs.sh [kuma|kibana|grafana]"
echo ""
echo -e "${CYAN}Quick Setup:${NC}"
echo "  1. Edit your URLs in ~/kiosk/env/*.env files"
echo "  2. Start a kiosk: ~/kiosk/scripts/switch-kiosk.sh kuma"
echo "  3. Or use interactive manager: ~/kiosk/scripts/manager.sh"
echo ""
echo -e "${CYAN}Rotation Commands:${NC}"
echo "  Portrait (recommended): ~/kiosk/scripts/set-default-rotation.sh 270"
echo "  Landscape:             ~/kiosk/scripts/set-default-rotation.sh normal"
echo ""
echo "System will restart in 30 seconds to apply all changes."
echo "After restart, your portrait kiosk will be ready!"
echo ""
echo "Press Ctrl+C to cancel reboot and setup manually..."
sleep 30
sudo reboot