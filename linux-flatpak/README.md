# Discord Drover for Linux (Flatpak) - Direct Mode

Discord Drover for Linux is a library that enables Discord voice chat in regions where it's blocked by manipulating UDP traffic. This is the Linux equivalent of the Windows "Direct mode" feature.

## What is Direct Mode?

Direct mode is a feature that helps bypass voice chat restrictions without using a proxy. It works by sending two small UDP packets before Discord's voice data, which helps bypass certain network restrictions. This is particularly useful in regions like the UAE where Discord works but voice chat is blocked.

## Requirements

- Discord installed via Flatpak (`com.discordapp.Discord`)
- GCC compiler
- Linux system with LD_PRELOAD support

## Installation

### 1. Build the library

```bash
cd linux-flatpak
./build.sh
```

This will create `libdrover.so` in the `linux-flatpak` directory.

### 2. Install for Flatpak Discord

Run the installation script:

```bash
./install-flatpak.sh
```

This script will:
- Build the library if not already built
- Install the library to the Flatpak override directory
- Configure Flatpak to use LD_PRELOAD with Discord

### 3. Restart Discord

After installation, completely quit Discord (including from system tray) and restart it. The drover library will now be active.

## How It Works

The library uses `LD_PRELOAD` to intercept socket system calls made by Discord. When Discord creates a UDP socket and sends its first voice packet (74 bytes), the library automatically sends two small packets (0 and 1 byte) before it. This manipulation helps bypass network restrictions on UDP voice traffic.

Key features:
- **No proxy required**: Works without any proxy configuration
- **Automatic**: Once installed, it works transparently with Discord
- **UDP-only manipulation**: Only affects UDP voice traffic, not regular messages
- **Flatpak compatible**: Designed to work with Flatpak's sandboxing

## Configuration

Currently, the library operates in Direct Mode only (no proxy support). Future versions may add proxy configuration similar to the Windows version.

The library expects a `drover.ini` file in the same directory (reserved for future use):

```ini
[drover]
# Proxy configuration (not yet implemented on Linux)
proxy = 
```

## Uninstallation

To remove Discord Drover:

```bash
./uninstall-flatpak.sh
```

This will remove the Flatpak override and library files.

## Technical Details

### How LD_PRELOAD Works

`LD_PRELOAD` is a Linux feature that allows you to load a shared library before any other libraries. This lets us intercept standard library functions like `socket()` and `sendto()` before Discord calls them.

### Flatpak Integration

Flatpak runs applications in a sandbox. To use LD_PRELOAD with Flatpak Discord, we:
1. Place the library in a location accessible to the Flatpak sandbox
2. Use `flatpak override` to set the LD_PRELOAD environment variable
3. Grant necessary permissions for the library to function

### UDP Manipulation

The library watches for:
- UDP socket creation (`socket()` with SOCK_DGRAM)
- First sendto on each socket with exactly 74 bytes (Discord voice packet size)
- When detected, sends two small packets (0 and 1 byte payloads) before the actual packet

This is the same technique used by the Windows version in Direct Mode.

## Troubleshooting

### Discord voice still doesn't work

1. Make sure Discord is completely closed (including system tray) before restarting
2. Check if the override is applied: `flatpak override --show com.discordapp.Discord`
3. Look for initialization message in logs: `journalctl -f | grep drover`

### Library not loading

1. Verify the library exists: `ls -l ~/.var/app/com.discordapp.Discord/drover/libdrover.so`
2. Check library dependencies: `ldd libdrover.so`
3. Verify permissions: `chmod 755 ~/.var/app/com.discordapp.Discord/drover/libdrover.so`

### Flatpak Discord not found

Make sure Discord is installed via Flatpak:
```bash
flatpak list | grep -i discord
```

If not installed, install it with:
```bash
flatpak install flathub com.discordapp.Discord
```

## Comparison with Windows Version

| Feature | Windows | Linux (Flatpak) |
|---------|---------|-----------------|
| Direct Mode (UDP manipulation) | ✅ | ✅ |
| HTTP Proxy | ✅ | ❌ (planned) |
| SOCKS5 Proxy | ✅ | ❌ (planned) |
| Proxy Authentication | ✅ | ❌ (planned) |
| Installation Method | DLL injection | LD_PRELOAD |
| GUI Installer | ✅ | ❌ (CLI only) |

## Building from Source

Requirements:
- GCC
- Make
- POSIX threads (pthread)

Build command:
```bash
gcc -shared -fPIC -o libdrover.so drover.c -ldl -lpthread
```

## License

This project follows the same license as the main Discord Drover project.

## Credits

Linux port based on the Windows Discord Drover by hdrover.
Original project: https://github.com/hdrover/discord-drover
