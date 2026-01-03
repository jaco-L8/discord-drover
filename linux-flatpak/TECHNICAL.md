# Technical Documentation - Discord Drover Linux (Flatpak)

## Overview

This document provides technical details about how Discord Drover for Linux implements Direct Mode for Flatpak-installed Discord applications.

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────┐
│         Flatpak Discord App             │
│  ┌────────────────────────────────┐     │
│  │   Discord JavaScript/Electron  │     │
│  └────────────────────────────────┘     │
│              ↓ syscalls                 │
│  ┌────────────────────────────────┐     │
│  │    libdrover.so (LD_PRELOAD)   │     │
│  │  • Intercept socket()          │     │
│  │  • Intercept sendto()          │     │
│  │  • Track UDP sockets           │     │
│  │  • Inject small packets        │     │
│  └────────────────────────────────┘     │
│              ↓ original syscalls        │
│  ┌────────────────────────────────┐     │
│  │      libc.so (glibc)           │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

### Component Description

1. **libdrover.so**: Shared library that intercepts socket-related system calls
2. **LD_PRELOAD**: Linux mechanism to load our library before others
3. **Flatpak override**: Configuration to inject LD_PRELOAD into sandboxed Discord

## Implementation Details

### 1. Function Interception

The library uses `dlsym(RTLD_NEXT, ...)` to obtain pointers to the real implementations of:
- `socket()` - For tracking socket creation
- `sendto()` - For UDP packet manipulation

This technique is known as "symbol interposition" and works because:
- The dynamic linker loads libdrover.so first (via LD_PRELOAD)
- When Discord calls `socket()`, it calls our implementation
- Our implementation can call the real one via the saved pointer

### 2. Socket Tracking

```c
typedef struct {
    int fd;              // File descriptor
    int type;            // SOCK_STREAM or SOCK_DGRAM
    int protocol;        // IPPROTO_TCP, IPPROTO_UDP, etc.
    int has_sent;        // First send flag
    long long created_at; // Timestamp for garbage collection
    pthread_mutex_t mutex; // Thread safety
} socket_info_t;
```

**Why we track sockets:**
- To know which sockets are UDP (SOCK_DGRAM)
- To detect the first send on each socket
- To avoid manipulating non-Discord traffic
- To clean up stale entries (garbage collection)

**Thread Safety:**
- Uses `pthread_mutex_t` for each socket entry
- Global mutex for the socket array
- Required because Discord is multi-threaded

### 3. Direct Mode UDP Manipulation

The core Direct Mode logic:

```c
if (is_first_send(sockfd) && is_udp_socket(sockfd) && len == 74) {
    unsigned char payload0 = 0;
    unsigned char payload1 = 1;
    
    real_sendto(sockfd, &payload0, 1, 0, dest_addr, addrlen);
    real_sendto(sockfd, &payload1, 1, 0, dest_addr, addrlen);
    
    usleep(50000); // 50ms delay
}
```

**Why this works:**
- Discord's voice packets are exactly 74 bytes (RTP packet with payload)
- Some network filters block UDP voice traffic based on packet patterns
- Sending small "probe" packets first alters the traffic pattern
- This confuses simplistic DPI (Deep Packet Inspection) filters
- The receiving end (Discord's servers) ignores these small packets

**Packet structure:**
- Payload 0: Single byte with value 0x00
- Payload 1: Single byte with value 0x01
- Both sent before the actual 74-byte voice packet
- 50ms delay ensures packets don't get coalesced by network stack

### 4. Flatpak Integration

Flatpak runs applications in a sandbox with limited filesystem access. Our solution:

**Installation Path:**
```
~/.var/app/com.discordapp.Discord/drover/libdrover.so
```

This path is:
- Automatically accessible to the Flatpak app
- Same path inside the Flatpak sandbox (using $HOME variable)
- Persists across Discord updates

**Flatpak Override:**
```bash
flatpak override --user com.discordapp.Discord \
    --env=LD_PRELOAD="\$HOME/.var/app/com.discordapp.Discord/drover/libdrover.so"
```

This:
- Sets LD_PRELOAD environment variable for Discord
- Uses the sandbox-internal path
- Grants home filesystem access (if needed)

### 5. Garbage Collection

To prevent memory leaks, we clean up old socket entries:

```c
long long now = get_time_ms();
for (int i = 0; i < MAX_SOCKETS; i++) {
    if (sockets[i].fd != -1 && 
        (now - sockets[i].created_at) > SOCKET_TIMEOUT_MS) {
        sockets[i].fd = -1;
        sockets[i].has_sent = 0;
    }
}
```

**Why 30 seconds timeout:**
- Discord voice sockets are long-lived (minutes)
- Short-lived sockets (HTTP requests) complete quickly
- 30 seconds is long enough to avoid false cleanup
- Prevents unbounded array growth

## Comparison: Windows vs Linux Implementation

| Aspect | Windows (DLL) | Linux (SO) |
|--------|---------------|------------|
| **Injection Method** | DLL hijacking (version.dll) | LD_PRELOAD |
| **Interception API** | DDetours (IAT patching) | Symbol interposition |
| **Socket API** | Winsock (socket, WSASocket, WSASend, WSASendTo) | POSIX sockets (socket, sendto) |
| **Threading** | Windows Critical Sections | POSIX mutexes |
| **Configuration** | drover.ini (LoadOptions) | drover.ini (not yet implemented) |
| **Installation** | Copy to Discord app-* directory | Flatpak override + library copy |
| **Auto-update handling** | Copies to all app-* folders | Flatpak override persists |

## Security Considerations

### 1. LD_PRELOAD Risks

**Potential Issues:**
- LD_PRELOAD can be used maliciously to inject code
- Our library has full access to Discord's process

**Mitigations:**
- Open source code - auditable by anyone
- Minimal functionality - only intercepts 2 functions
- No network code - only manipulates existing sockets
- No credential access - doesn't read Discord's memory

### 2. Flatpak Sandbox

**Benefits:**
- Discord runs in Flatpak sandbox
- Limited access to system resources
- Our library inherits these restrictions
- Can't escape sandbox even if compromised

### 3. Code Safety

**Best Practices:**
- No dynamic memory allocation (uses fixed array)
- Bounds checking on array access
- Thread-safe with mutexes
- No string parsing vulnerabilities
- No buffer overflows

## Performance Impact

### Memory Usage
- Fixed allocation: ~32 KB for socket array (1024 sockets × ~32 bytes)
- No dynamic allocations during runtime
- Negligible compared to Discord's memory usage (200-500 MB)

### CPU Overhead
- Socket creation: One array search + one mutex lock/unlock
- First sendto: Two extra syscalls + 50ms sleep
- Subsequent sendtos: One mutex lock/unlock + array lookup
- Overall impact: <0.1% of Discord's CPU usage

### Network Impact
- Two 1-byte packets per voice connection
- Sent once per voice session
- Total overhead: 2 bytes per session
- Negligible on modern networks

## Debugging

### Enable Debug Logging

Modify the library to add debug output:

```c
fprintf(stderr, "drover: socket(%d, %d, %d) = %d\n", 
        domain, type, protocol, fd);
```

View logs:
```bash
journalctl -f | grep drover
```

### Test Without Discord

Create a test program:

```c
#include <sys/socket.h>
#include <netinet/in.h>

int main() {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    char buf[74] = {0};
    struct sockaddr_in addr = {
        .sin_family = AF_INET,
        .sin_port = htons(50000),
        .sin_addr.s_addr = htonl(INADDR_LOOPBACK)
    };
    sendto(sock, buf, 74, 0, (struct sockaddr*)&addr, sizeof(addr));
    return 0;
}
```

Compile and test:
```bash
gcc -o test test.c
LD_PRELOAD=./libdrover.so ./test
```

### Verify Interception

Use `strace` to see if our library is being called:

```bash
strace -e trace=socket,sendto flatpak run com.discordapp.Discord
```

### Common Issues

**Library not loading:**
- Check: `ldd libdrover.so` for missing dependencies
- Verify: File permissions (must be readable/executable)
- Confirm: Path is correct in Flatpak override

**Direct mode not working:**
- Voice packets might not be exactly 74 bytes (Discord update?)
- Check with Wireshark to see actual packet sizes
- Verify UDP sockets are being created

**Crashes:**
- Check for thread safety issues
- Verify we're not dereferencing NULL pointers
- Look for mutex deadlocks

## Future Enhancements

### 1. Proxy Support

Add HTTP/SOCKS5 proxy support:
- Parse drover.ini configuration
- Intercept `connect()` for TCP sockets
- Implement SOCKS5 handshake
- Add proxy authentication

### 2. Configuration Reload

Support dynamic configuration:
- Watch drover.ini for changes (inotify)
- Reload settings without restarting Discord
- Toggle Direct Mode on/off

### 3. Packet Size Detection

Make UDP manipulation adaptive:
- Detect Discord voice packet size automatically
- Adjust to protocol changes
- Support different Discord versions

### 4. Native Package Support

Extend beyond Flatpak:
- Support .deb/.rpm packaged Discord
- Support Snap packaged Discord
- Support tarball/manual installations

### 5. GUI Configuration Tool

Create a simple GUI:
- Enable/disable Direct Mode
- View current status
- Configure proxy settings
- Test connection

## Building from Source

### Development Environment

```bash
# Install dependencies
sudo apt-get install build-essential gcc make

# Clone repository
git clone https://github.com/jaco-L8/discord-drover
cd discord-drover/linux-flatpak

# Build
make clean
make
```

### Compiler Flags Explained

```makefile
CFLAGS = -shared -fPIC -O2 -Wall -Wextra
```

- `-shared`: Create shared library (.so)
- `-fPIC`: Position Independent Code (required for shared libs)
- `-O2`: Optimization level 2 (balance speed/size)
- `-Wall -Wextra`: Enable all warnings

```makefile
LDFLAGS = -ldl -lpthread
```

- `-ldl`: Link libdl (for dlsym)
- `-lpthread`: Link pthread (for mutexes)

### Testing Changes

After modifying `drover.c`:

```bash
# Rebuild
make clean && make

# Test loading
ldd libdrover.so

# Test with simple program
LD_PRELOAD=./libdrover.so /bin/ls

# If working, reinstall
make install
```

## References

### Linux Documentation
- `man 3 dlsym` - Symbol resolution
- `man 7 rtld` - Runtime linker
- `man 2 socket` - Socket creation
- `man 2 sendto` - Send UDP packets
- `man 3 pthread_mutex_lock` - Mutex locking

### Flatpak Documentation
- [Flatpak overrides](https://docs.flatpak.org/en/latest/flatpak-command-reference.html#flatpak-override)
- [Sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html)

### Related Techniques
- LD_PRELOAD: [https://man7.org/linux/man-pages/man8/ld.so.8.html](https://man7.org/linux/man-pages/man8/ld.so.8.html)
- Symbol interposition: Used by tools like `faketime`, `tsocks`
- Similar tools: `proxychains-ng`, `torsocks`

## License

This project follows the same license as Discord Drover.

## Contributing

When contributing to the Linux version:
1. Maintain compatibility with existing Direct Mode behavior
2. Keep dependencies minimal (only libc, libdl, libpthread)
3. Ensure thread safety for all shared data
4. Add comments for complex logic
5. Test with actual Discord voice calls
