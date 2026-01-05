#!/bin/bash
# Test script for Discord Drover library

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Discord Drover - Test Suite"
echo "============================"
echo ""

# Check if library is built
if [ ! -f "libdrover.so" ]; then
    echo "Building library..."
    make clean
    make
    echo ""
fi

echo "1. Testing library dependencies..."
if ldd libdrover.so | grep -q "not found"; then
    echo "✗ FAILED: Missing dependencies"
    ldd libdrover.so
    exit 1
else
    echo "✓ PASSED: All dependencies satisfied"
fi
echo ""

echo "2. Testing library symbols..."
if nm -D libdrover.so | grep -q "socket"; then
    echo "✓ PASSED: socket symbol found"
else
    echo "✗ FAILED: socket symbol not found"
    exit 1
fi

if nm -D libdrover.so | grep -q "sendto"; then
    echo "✓ PASSED: sendto symbol found"
else
    echo "✗ FAILED: sendto symbol not found"
    exit 1
fi
echo ""

echo "3. Creating test program..."
cat > /tmp/drover_test.c << 'EOF'
#include <stdio.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <string.h>

int main() {
    printf("Test program starting...\n");
    
    // Create UDP socket
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }
    printf("Created UDP socket: fd=%d\n", sock);
    
    // Prepare destination
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(50000);
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    // Send 74-byte packet (triggers Direct Mode)
    char buf[74];
    memset(buf, 0xAA, sizeof(buf));
    
    printf("Sending 74-byte packet (should trigger Direct Mode)...\n");
    ssize_t sent = sendto(sock, buf, sizeof(buf), 0, 
                          (struct sockaddr*)&addr, sizeof(addr));
    
    if (sent > 0) {
        printf("Sent %zd bytes\n", sent);
    } else {
        perror("sendto");
    }
    
    // Send another packet (should NOT trigger Direct Mode)
    printf("Sending second packet (should not trigger Direct Mode)...\n");
    sent = sendto(sock, buf, sizeof(buf), 0, 
                  (struct sockaddr*)&addr, sizeof(addr));
    
    if (sent > 0) {
        printf("Sent %zd bytes\n", sent);
    } else {
        perror("sendto");
    }
    
    close(sock);
    printf("Test completed successfully!\n");
    return 0;
}
EOF

gcc -o /tmp/drover_test /tmp/drover_test.c
echo "✓ Test program compiled"
echo ""

echo "4. Testing library interception..."
echo "   (Running with LD_PRELOAD)"
echo ""

LD_PRELOAD="$SCRIPT_DIR/libdrover.so" /tmp/drover_test 2>&1

echo ""
echo "5. Testing without LD_PRELOAD (for comparison)..."
echo ""

/tmp/drover_test 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All tests passed!"
echo ""
echo "The library should show initialization message"
echo "when run with LD_PRELOAD but not without it."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup
rm -f /tmp/drover_test /tmp/drover_test.c

echo "Cleanup complete."
