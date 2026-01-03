/*
 * Discord Drover for Linux (Flatpak) - Direct Mode
 * 
 * This library intercepts socket calls to manipulate UDP traffic for Discord,
 * enabling voice chat in regions where it's blocked (similar to Direct mode on Windows).
 * 
 * Uses LD_PRELOAD to inject into Discord process.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>

#define MAX_SOCKETS 1024
#define SOCKET_TIMEOUT_MS 30000
#define INI_FILENAME "drover.ini"

// Socket tracking structure
typedef struct {
    int fd;
    int type;
    int protocol;
    int has_sent;
    long long created_at;
    pthread_mutex_t mutex;
} socket_info_t;

// Global socket manager
static socket_info_t sockets[MAX_SOCKETS];
static pthread_mutex_t sockets_mutex = PTHREAD_MUTEX_INITIALIZER;
static int initialized = 0;

// Original function pointers
static int (*real_socket)(int domain, int type, int protocol) = NULL;
static ssize_t (*real_sendto)(int sockfd, const void *buf, size_t len, int flags,
                               const struct sockaddr *dest_addr, socklen_t addrlen) = NULL;

// Get current time in milliseconds
static long long get_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

// Initialize the library
static void init_drover(void) __attribute__((constructor));
static void init_drover(void) {
    if (initialized) return;
    
    // Load original functions
    real_socket = dlsym(RTLD_NEXT, "socket");
    real_sendto = dlsym(RTLD_NEXT, "sendto");
    
    if (!real_socket || !real_sendto) {
        fprintf(stderr, "drover: Failed to load original socket functions\n");
        return;
    }
    
    // Initialize socket tracking array
    pthread_mutex_lock(&sockets_mutex);
    for (int i = 0; i < MAX_SOCKETS; i++) {
        sockets[i].fd = -1;
        sockets[i].has_sent = 0;
        pthread_mutex_init(&sockets[i].mutex, NULL);
    }
    pthread_mutex_unlock(&sockets_mutex);
    
    initialized = 1;
    
    fprintf(stderr, "drover: Initialized for Discord Direct Mode\n");
}

// Find socket info by fd
static socket_info_t* find_socket(int fd) {
    for (int i = 0; i < MAX_SOCKETS; i++) {
        if (sockets[i].fd == fd) {
            return &sockets[i];
        }
    }
    return NULL;
}

// Add socket to tracking
static void add_socket(int fd, int type, int protocol) {
    pthread_mutex_lock(&sockets_mutex);
    
    // Clean up old sockets
    long long now = get_time_ms();
    for (int i = 0; i < MAX_SOCKETS; i++) {
        if (sockets[i].fd != -1 && 
            (now - sockets[i].created_at) > SOCKET_TIMEOUT_MS) {
            sockets[i].fd = -1;
            sockets[i].has_sent = 0;
        }
    }
    
    // Find empty slot or existing entry
    socket_info_t *info = find_socket(fd);
    if (!info) {
        for (int i = 0; i < MAX_SOCKETS; i++) {
            if (sockets[i].fd == -1) {
                info = &sockets[i];
                break;
            }
        }
    }
    
    if (info) {
        pthread_mutex_lock(&info->mutex);
        info->fd = fd;
        info->type = type;
        info->protocol = protocol;
        info->has_sent = 0;
        info->created_at = get_time_ms();
        pthread_mutex_unlock(&info->mutex);
    }
    
    pthread_mutex_unlock(&sockets_mutex);
}

// Check if this is the first send on a socket
static int is_first_send(int fd) {
    pthread_mutex_lock(&sockets_mutex);
    socket_info_t *info = find_socket(fd);
    
    if (info && !info->has_sent) {
        pthread_mutex_lock(&info->mutex);
        info->has_sent = 1;
        pthread_mutex_unlock(&info->mutex);
        pthread_mutex_unlock(&sockets_mutex);
        return 1;
    }
    
    pthread_mutex_unlock(&sockets_mutex);
    return 0;
}

// Check if socket is UDP
static int is_udp_socket(int fd) {
    pthread_mutex_lock(&sockets_mutex);
    socket_info_t *info = find_socket(fd);
    int result = 0;
    
    if (info) {
        result = (info->type == SOCK_DGRAM && 
                  (info->protocol == IPPROTO_UDP || info->protocol == 0));
    }
    
    pthread_mutex_unlock(&sockets_mutex);
    return result;
}

// Intercepted socket function
int socket(int domain, int type, int protocol) {
    if (!initialized) init_drover();
    
    int fd = real_socket(domain, type, protocol);
    
    if (fd >= 0) {
        add_socket(fd, type, protocol);
    }
    
    return fd;
}

// Intercepted sendto function - implements Direct Mode UDP manipulation
ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
               const struct sockaddr *dest_addr, socklen_t addrlen) {
    if (!initialized) init_drover();
    
    // Debug: Log UDP sends to help diagnose Direct Mode issues
    int is_udp = is_udp_socket(sockfd);
    int is_first = is_first_send(sockfd);
    
    if (is_udp && len > 0 && len < 200) {
        fprintf(stderr, "drover: [DEBUG] UDP send - FD=%d, len=%zu, first=%d\n", 
                sockfd, len, is_first);
    }
    
    // Check if this is the first send on a UDP socket with 74-byte payload
    // This is the Discord voice packet signature
    if (is_first && is_udp && len == 74) {
        fprintf(stderr, "drover: [DIRECT MODE] Activating! Sending probe packets before 74-byte UDP packet\n");
        
        // Send two small packets before the actual data
        // This helps bypass some network restrictions on UDP voice traffic
        unsigned char payload0 = 0;
        unsigned char payload1 = 1;
        
        real_sendto(sockfd, &payload0, 1, 0, dest_addr, addrlen);
        real_sendto(sockfd, &payload1, 1, 0, dest_addr, addrlen);
        
        fprintf(stderr, "drover: [DIRECT MODE] Probe packets sent successfully\n");
        
        // Small delay to ensure packets are sent in order
        usleep(50000); // 50ms
    }
    
    return real_sendto(sockfd, buf, len, flags, dest_addr, addrlen);
}
