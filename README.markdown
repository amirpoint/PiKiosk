# Raspberry Pi Multi-Kiosk Setup with Portrait Mode

This project provides a Bash script (`portrait_kiosk_setup_v2.sh`) to configure a Raspberry Pi as a multi-kiosk system, designed to display web dashboards (e.g., Uptime Kuma, Kibana, Grafana) in a browser with support for persistent display rotation, particularly optimized for portrait mode. The script sets up a robust kiosk environment with an interactive manager for switching between dashboards and controlling screen rotation using `wlr-randr`.

## Features

- **Multi-Kiosk Support**: Configures and switches between multiple web dashboards (Uptime Kuma, Kibana, Grafana by default).
- **Persistent Display Rotation**: Uses `wlr-randr` to manage screen rotation (portrait or landscape) that persists after reboot.
- **Interactive Manager**: A user-friendly script (`manager.sh`) to switch kiosks, toggle rotation, and view system status.
- **Automatic Display Detection**: Detects the display output (e.g., HDMI-A-1) for rotation configuration.
- **Error Handling & Logging**: Improved logging and error handling for reliable operation.
- **Systemd Integration**: Uses systemd services for automatic startup and rotation persistence.
- **Customizable Environment Files**: Easily configure URLs and rotation settings for each kiosk.

## Prerequisites

- Raspberry Pi (tested on Raspberry Pi OS).
- Internet connection for package installation.
- Run the script as a **non-root user** with `sudo` privileges.

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo
   ```

2. **Run the Setup Script**:
   ```bash
   chmod +x portrait_kiosk_setup_v2.sh
   ./portrait_kiosk_setup_v2.sh
   ```

   The script will:
   - Install required packages (`chromium-browser`, `wlr-randr`, etc.).
   - Create necessary directories and configuration files.
   - Set up systemd services for rotation persistence and kiosk modes.
   - Configure default portrait rotation (270°).
   - Enable auto-login and disable screen blanking.

3. **Edit Environment Files**:
   Update the URLs for your dashboards in the following files:
   ```bash
   nano ~/kiosk/env/kuma.env
   nano ~/kiosk/env/kibana.env
   nano ~/kiosk/env/grafana.env
   ```

   Example `kuma.env`:
   ```bash
   KIOSK_NAME="Uptime Kuma"
   KIOSK_URL="http://your-uptime-kuma-url/dashboard"
   ROTATION_MODE="270"
   ```

4. **Start a Kiosk**:
   Launch a specific kiosk (e.g., Uptime Kuma):
   ```bash
   ~/kiosk/scripts/switch-kiosk.sh kuma
   ```

5. **Use the Interactive Manager** (recommended):
   ```bash
   ~/kiosk/scripts/manager.sh
   ```

   The manager provides a menu to:
   - Switch between kiosks (Uptime Kuma, Kibana, Grafana).
   - Change display rotation (landscape, portrait, etc.).
   - View system and display status.
   - Stop or restart kiosks.

## Managing Rotation

The script supports persistent display rotation using `wlr-randr`. The default rotation is set to **portrait-right (270°)**, but you can change it:

- **Set Portrait Mode** (default):
  ```bash
  ~/kiosk/scripts/set-default-rotation.sh 270
  ```

- **Set Landscape Mode**:
  ```bash
  ~/kiosk/scripts/set-default-rotation.sh normal
  ```

- **Toggle Rotation**:
  ```bash
  ~/kiosk/scripts/toggle-rotation.sh [normal|90|180|270]
  ```

- **Check Rotation and System Status**:
  ```bash
  ~/kiosk/scripts/check-status.sh
  ```

## Available Scripts

- `switch-kiosk.sh [kuma|kibana|grafana] [rotation]`: Switches to the specified kiosk with an optional rotation setting.
- `set-default-rotation.sh [normal|90|180|270]`: Sets and saves the default rotation for all kiosks.
- `toggle-rotation.sh [normal|90|180|270]`: Toggles rotation and updates all kiosk configurations.
- `check-status.sh`: Displays the status of kiosk services, rotation service, and display settings.
- `view-logs.sh [kuma|kibana|grafana]`: Shows logs for the specified kiosk.
- `manager.sh`: Launches the interactive management interface.

## Logs

- **Rotation Logs**:
  - Startup: `~/kiosk/rotation-startup.log`
  - Changes: `~/kiosk/rotation.log`
- **Kiosk Logs**: Available via `journalctl` or `view-logs.sh`.

## Notes

- The script auto-detects the display output (defaults to `HDMI-A-1` if detection fails).
- Rotation persists across reboots via the `kiosk-rotation.service` systemd service.
- Ensure your URLs in `*.env` files are correct to avoid loading errors.
- The system will reboot 30 seconds after setup to apply changes (press `Ctrl+C` to cancel).

## Contributing

Feel free to open issues or submit pull requests to improve this project. Suggestions for additional features or bug fixes are welcome!

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.