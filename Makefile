.PHONY: build test clean install help

# Variables
CLI_NAME := outlook-md
BIN_DIR := bin
CLI_PATH := $(BIN_DIR)/$(CLI_NAME)
INSTALL_PATH := /usr/local/bin/$(CLI_NAME)

# Go parameters
GOCMD := go
GOBUILD := $(GOCMD) build
GOTEST := $(GOCMD) test
GOCLEAN := $(GOCMD) clean
GOMOD := $(GOCMD) mod

# Build the CLI binary
build: deps
	@echo "Building $(CLI_NAME)..."
	@mkdir -p $(BIN_DIR)
	cd outlook-md && $(GOBUILD) -o ../$(CLI_PATH) ./cmd/outlook-md
	@echo "Built: $(CLI_PATH)"

# Run all tests (Go + Lua)
test:
	@echo "Running Go tests..."
	cd outlook-md && $(GOTEST) -v ./...
	@echo "Running Lua tests..."
	@echo "Note: Lua tests require plenary.nvim and Neovim"
	@# TODO: Add Lua test invocation via nvim --headless or plenary test harness

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BIN_DIR)
	cd outlook-md && $(GOCLEAN)
	@echo "Clean complete"

# Install CLI binary to system path (requires sudo)
install: build
	@echo "Installing $(CLI_NAME) to $(INSTALL_PATH)..."
	@sudo cp $(CLI_PATH) $(INSTALL_PATH)
	@sudo chmod 755 $(INSTALL_PATH)
	@echo "Installed: $(INSTALL_PATH)"

# Download Go dependencies
deps:
	@echo "Downloading Go dependencies..."
	cd outlook-md && $(GOMOD) download
	cd outlook-md && $(GOMOD) tidy

# Help target
help:
	@echo "Available targets:"
	@echo "  build    - Build the outlook-md CLI binary to ./bin/"
	@echo "  test     - Run all tests (Go + Lua)"
	@echo "  clean    - Remove build artifacts"
	@echo "  install  - Install CLI to /usr/local/bin (requires sudo)"
	@echo "  deps     - Download and tidy Go dependencies"
	@echo "  help     - Show this help message"
