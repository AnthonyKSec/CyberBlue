# CyberBlue CyberForge — Raptor DFIR GUI Launcher v2

**Module:** 09 — Endpoint Forensics & Threat Hunting  
**Platform:** Pop!_OS / GNOME, RhinoRecon workstation  
**Status:** Operator-validated on October 15, 2026. Both Start menu and desktop shortcut successfully opened the protected Velociraptor GUI following SSH authentication.

## Principle before platform

Secure administrative access should be repeatable **without exposing sensitive management ports to the network**. This launcher creates or reuses a local SSH port forward, waits for Velociraptor to respond, and opens the browser in the graphical desktop session. Velociraptor's administrative GUI remains bound to the DFIR-01 loopback address.

| Component | Role |
| --- | --- |
| cyberblue-dfir | Launch and readiness orchestration from both desktop entry points |
| cyberblue-dfir-start-tunnel | Interactive authentication and detached SSH tunnel |
| SSH alias dfir-gui | User-configured SSH host, credentials, and local port forward |
| install.sh | Per-user deployment of scripts, icon and identical menu/desktop entries |
| cyberblue-raptor-dfir.png | Optimized launcher icon |
| Local port 18889 | RhinoRecon browser endpoint, forwarded to DFIR-01 127.0.0.1:8889 |
| Local log | ~/.cache/cyberblue-dfir/launcher.log |

## Security architecture

RhinoRecon browser at https://127.0.0.1:18889
   → local SSH tunnel (alias dfir-gui)
   → DFIR-01 GUI at 127.0.0.1:8889

No server configuration, Proxmox VM, client enrollment, firewall, or network exposure is changed by this installer. The actual management IP address, private keys, and passwords are excluded from the repository.

## Requirements

- GNOME/Pop!_OS or compatible graphical Linux session
- ssh, ss, curl and xdg-open
- gnome-terminal, xterm or konsole for first-time SSH prompts
- Authorized SSH access to DFIR-01 and working Velociraptor GUI
- A local SSH alias named dfir-gui, configured privately in ~/.ssh/config

Example SSH configuration. Replace the placeholders with your own environment details:

~~~sshconfig
Host dfir-gui
    HostName <DFIR-01-management-IP>
    User <your-SSH-username>
    LocalForward 127.0.0.1:18889 127.0.0.1:8889
    ExitOnForwardFailure yes
    ServerAliveInterval 30
    ServerAliveCountMax 3
~~~

## Install or update

From a local clone of the CyberBlue repository:

~~~bash
cd tools/dfir-gui-launcher
bash install.sh
~~~

The installer installs binaries under ~/.local/bin and ~/.local/libexec; creates the application menu launcher under ~/.local/share/applications; installs the icon under ~/.local/share/icons; and creates a Desktop shortcut if ~/Desktop exists. No sudo needed. On GNOME, choose **Allow Launching** if the desktop shortcut is initially untrusted.

## Validation — October 15, 2026

1. Existing tunnel on local port 18889 was manually identified and stopped before testing.
2. Operator launched the **Start menu** entry and entered SSH credentials; Velociraptor opened.
3. Operator tested the **desktop icon** independently and confirmed the same behavior.
4. The user reported that both paths work. These are operator-observed functional tests, not automated security tests.

## Troubleshooting

- Read ~/.cache/cyberblue-dfir/launcher.log
- Test the SSH alias by manually running: ssh -N dfir-gui
- Inspect the specific listener: ss -ltnp | grep ':18889'
- Do not kill all SSH connections; close only your DFIR tunnel
- If an SSH prompt appears but GUI doesn't open, check Velociraptor service readiness and the browser session

## Safety and limits

This is a **training-range administrative access helper**, not a public-internet deployment system. The script uses curl --insecure only to test whether the local HTTPS endpoint responds; that is not authentication or a guarantee the endpoint is Velociraptor. Check the SSH endpoint and GUI certificate through your approved trust process. No passwords, private keys, enrollment nonces, or privileged server/client configuration should be committed.

The included PNG is an optimized small launcher asset; the full-resolution original is preserved in the local v2 distribution package.

## Capability summary

Repeatable least-exposure GUI access via explicit SSH transport and two consistent graphical entry points; source-controlled and documented for reproducibility. **Module 09 Windows client enrollment and end-to-end hunting qualification remain open.**
