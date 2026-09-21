# Camera Blur

Camera Blur adds NV Broadcast controls to the Omarchy bar. It shows status and previews the processed virtual camera.

The plugin does not process video. It controls the separate [NV Broadcast](https://github.com/Hkshoonya/nvidia-broadcast-linux) application.

![Camera Blur panel](preview.png)

## Features

- Toggle background blur from the bar.
- Start, stop, or open NV Broadcast.
- Show application, virtual-camera, stream, and blur status.
- Preview the processed `/dev/video10` feed.

## Requirements

- Omarchy 4 or later
- NV Broadcast from the tested source revision below
- `v4l2loopback`
- `qt6-multimedia`
- An NVIDIA GPU for CUDA processing

NV Broadcast is an unofficial NVIDIA Broadcast alternative. Its GPL-3.0 license and upstream security model apply separately.

## Install NV Broadcast

The AUR package does not contain the remote actions that this plugin needs. Install the tested source revision:

```bash
git clone https://github.com/Hkshoonya/nvidia-broadcast-linux.git nvidia-broadcast-linux &&
git -C nvidia-broadcast-linux checkout --detach 328c318fd260e1bea01e87f184023fba69c172c3 &&
cd nvidia-broadcast-linux &&
./install.sh --runtime cuda
```

The source installer installs packages and configures `/dev/video10`. Review the upstream installer before you run it.

### Enable remote control on Hyprland

NV Broadcast disables its application actions when the GlobalShortcuts portal rejects registration. Hyprland currently triggers this condition.

Change `src/nvbroadcast/app.py` in `NVBroadcastApp._set_global_hotkey_actions_enabled`:

```python
action.set_enabled(True)  # Replace action.set_enabled(bool(enabled))
```

Activate the edited source in the existing environment:

```bash
.venv/bin/pip install -e . --no-deps
```

Restart NV Broadcast after this change. The plugin then calls this application action:

```bash
gapplication action com.doczeus.NVBroadcast toggle-background
```

This workaround changes the third-party application. Reapply or remove it when you update NV Broadcast.

## Install the plugin

```bash
omarchy plugin add https://github.com/kyryl-bogach/omarchy-camera-blur.git --enable
```

## Use the plugin

Left-click the bar icon to toggle blur. If NV Broadcast is stopped, left-click opens the panel.

Middle-click or right-click opens the panel. The panel contains the preview, status, and application controls.

NV Broadcast streams only while its window is open. Leave the window open on another workspace during use.

Set `minimize_on_close = false` in `~/.config/nvbroadcast/config.toml`. Closing the window then stops the application instead of its stream only.

If the first preview cannot find `/dev/video10`, restart the Omarchy shell once:

```bash
omarchy restart shell
```

Qt caches camera discovery in the shell process. Later logins discover the virtual camera during shell startup.

## Select the camera in each application

Select **NVbroadcast** in applications that need the processed feed. Select the physical camera when you do not need processing.

Some Chromium versions hide loopback cameras behind the PipeWire camera flag. Disable that flag if `NVbroadcast` does not appear.

## Privacy and permissions

The plugin runs unsandboxed inside the Omarchy shell. It can start or stop NV Broadcast and read its local configuration.

The plugin does not use the network. NV Broadcast can download models and has its own privacy and security behavior.

## Remove

```bash
omarchy plugin remove io.github.kyryl-bogach.camera-blur
```

This command removes only the plugin. Remove NV Broadcast and `v4l2loopback` separately if you no longer need them.

## Develop

Validate the manifest and run the model tests:

```bash
omarchy plugin validate .
/usr/lib/qt6/bin/qmltestrunner -input tests -import .
```

## License

This plugin uses the MIT license. NV Broadcast remains a separate GPL-3.0 project.
