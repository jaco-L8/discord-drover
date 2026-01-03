# Compiler
CC = gcc

# Compiler flags
CFLAGS = -shared -fPIC -O2 -Wall -Wextra

# Linker flags
LDFLAGS = -ldl -lpthread

# Source and output
SRC = drover.c
OUT = libdrover.so

# Default target
all: $(OUT)

# Build the shared library
$(OUT): $(SRC)
	$(CC) $(CFLAGS) -o $(OUT) $(SRC) $(LDFLAGS)
	@echo "Build complete: $(OUT)"

# Clean build artifacts
clean:
	rm -f $(OUT)
	@echo "Cleaned build artifacts"

# Install to Flatpak Discord
install: $(OUT)
	@bash install-flatpak.sh

# Uninstall from Flatpak Discord
uninstall:
	@bash uninstall-flatpak.sh

# Help
help:
	@echo "Discord Drover for Linux (Flatpak) - Build System"
	@echo ""
	@echo "Targets:"
	@echo "  make          - Build the library"
	@echo "  make clean    - Remove build artifacts"
	@echo "  make install  - Build and install to Flatpak Discord"
	@echo "  make uninstall - Remove from Flatpak Discord"
	@echo "  make help     - Show this help message"

.PHONY: all clean install uninstall help
