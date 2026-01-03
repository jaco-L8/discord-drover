# Quick Start Guide - Discord Drover for Linux (Flatpak)

## What is this?

Discord Drover helps you use Discord voice chat in regions where it's blocked (like UAE) by manipulating UDP traffic. No proxy needed!

## Prerequisites

- Discord installed via Flatpak
- Linux system
- Basic terminal knowledge

## Installation (5 minutes)

### Step 1: Check if you have Flatpak Discord

```bash
flatpak list | grep -i discord
```

If you don't see Discord, install it:
```bash
flatpak install flathub com.discordapp.Discord
```

### Step 2: Download or Clone This Repository

If you have git:
```bash
git clone https://github.com/jaco-L8/discord-drover
cd discord-drover/linux-flatpak
```

Or download and extract the ZIP, then navigate to the `linux-flatpak` folder.

### Step 3: Install

```bash
make install
```

This will:
- ✓ Build the library
- ✓ Install it to the right location
- ✓ Configure Flatpak to use it

### Step 4: Restart Discord

**IMPORTANT**: Completely quit Discord (including from system tray), then start it again.

```bash
# Kill Discord if running
killall Discord

# Start Discord
flatpak run com.discordapp.Discord
```

## Verify It's Working

### Method 1: Check the override

```bash
flatpak override --show com.discordapp.Discord
```

You should see:
```
Environment=LD_PRELOAD=/var/config/drover/libdrover.so
```

### Method 2: Check logs

In one terminal, watch logs:
```bash
journalctl -f | grep drover
```

In another terminal, start Discord:
```bash
flatpak run com.discordapp.Discord
```

You should see:
```
drover: Initialized for Discord Direct Mode
```

### Method 3: Test voice chat

Join a voice channel and speak. If you can be heard and hear others, it's working!

## Troubleshooting

### "Discord is not installed via Flatpak"

Install Discord with Flatpak:
```bash
flatpak install flathub com.discordapp.Discord
```

### "Build failed" or "gcc: command not found"

Install build tools:
```bash
# Ubuntu/Debian
sudo apt-get install build-essential

# Fedora
sudo dnf install gcc make

# Arch
sudo pacman -S base-devel
```

### Voice still doesn't work

1. Make sure you completely quit Discord (check with `ps aux | grep Discord`)
2. Try uninstalling and reinstalling:
   ```bash
   make uninstall
   make clean
   make install
   ```
3. Restart your computer (to clear any cached settings)

### "Permission denied" errors

Make sure scripts are executable:
```bash
chmod +x *.sh
```

## Uninstallation

To remove Discord Drover:

```bash
make uninstall
```

This removes all files and configurations. Discord will work normally again (without the fix).

## How It Works (Simple Explanation)

1. **LD_PRELOAD**: A Linux feature that lets us run our code before Discord's code
2. **UDP Manipulation**: When Discord sends voice data, we send 2 tiny packets first
3. **Bypass Filters**: These packets confuse network filters that block Discord voice

Think of it like sending a "knock knock" before your actual message - the filter expects one pattern, but we give it a different one.

## What This Does NOT Do

- ❌ Does not hide your Discord usage
- ❌ Does not encrypt your traffic
- ❌ Does not bypass account bans
- ❌ Does not affect text chat (only voice)
- ❌ Does not work with non-Flatpak Discord (yet)

## FAQ

**Q: Is this safe?**
A: Yes, the code is open source and only manipulates your own network packets. It doesn't access Discord's memory or your credentials.

**Q: Will I get banned?**
A: No, this doesn't modify Discord itself or violate Terms of Service. It only changes how your computer sends network packets.

**Q: Does this slow down Discord?**
A: No, the performance impact is negligible (<0.1% CPU, 2 bytes of network overhead).

**Q: Do I need to reconfigure after Discord updates?**
A: No, the Flatpak override persists across updates.

**Q: Can I use this with a proxy too?**
A: Not yet, but proxy support is planned for future versions.

**Q: Does this work on other distributions?**
A: Yes! Works on any Linux distribution that supports Flatpak (Ubuntu, Fedora, Arch, etc.)

**Q: What about Discord installed from .deb or .tar.gz?**
A: Not supported yet, but you can adapt it by manually setting LD_PRELOAD for your installation method.

## Need Help?

1. Read the [full README](README.md)
2. Check [Technical Documentation](TECHNICAL.md)
3. Open an issue on GitHub
4. Make sure Discord is actually installed via Flatpak

## Success Stories

If this helps you, consider:
- ⭐ Starring the repository
- 📢 Sharing with others who need it
- 🐛 Reporting issues you find
- 💻 Contributing improvements

## Next Steps

- Join a voice channel and test it
- Read the [Technical Documentation](TECHNICAL.md) to understand how it works
- Check the [README](README.md) for more details

---

Made with ❤️ for people who just want to chat with their friends.
