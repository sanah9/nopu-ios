#!/bin/bash

# Set color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
FRAMEWORK_NAME="NopuFFI"
RUST_LIB_NAME="nopu_rust_ffi"
OUTPUT_DIR="../nopu"
BINDINGS_DIR="./bindings"

echo -e "${BLUE}Starting to build Nostr iOS Framework...${NC}"

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: Rust not installed, please install Rust first${NC}"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode not installed, please install Xcode first${NC}"
    exit 1
fi

# Install iOS targets
echo -e "${YELLOW}Adding iOS compilation targets...${NC}"
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add aarch64-apple-darwin

# Build Rust library
echo -e "${YELLOW}Building Rust library...${NC}"
cargo build --release

# Build for iOS targets
echo -e "${YELLOW}Building for iOS devices...${NC}"
cargo build --release --target aarch64-apple-ios

echo -e "${YELLOW}Building for iOS simulator...${NC}"
cargo build --release --target aarch64-apple-ios-sim

echo -e "${YELLOW}Building for macOS...${NC}"
cargo build --release --target aarch64-apple-darwin

# Generate Swift bindings
echo -e "${YELLOW}Generating Swift bindings...${NC}"
mkdir -p "${BINDINGS_DIR}"

# Use uniffi to generate bindings
echo "Attempting to generate Swift bindings..."
if command -v uniffi-bindgen &> /dev/null; then
    uniffi-bindgen generate src/nopu_ffi.udl --language swift --out-dir "${BINDINGS_DIR}"
else
    echo "uniffi-bindgen not found, please install first: cargo install uniffi-cli"
    exit 1
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate Swift bindings${NC}"
    exit 1
fi

# Prepare header files
echo -e "${YELLOW}Preparing header files...${NC}"
HEADER_DIR="${BINDINGS_DIR}/include"
mkdir -p "${HEADER_DIR}"

# Copy and rename files
cp "${BINDINGS_DIR}/${RUST_LIB_NAME}FFI.h" "${HEADER_DIR}/"
cp "${BINDINGS_DIR}/${RUST_LIB_NAME}FFI.modulemap" "${HEADER_DIR}/module.modulemap"

# Create XCFramework
echo -e "${YELLOW}Creating XCFramework...${NC}"
XCFRAMEWORK_PATH="${OUTPUT_DIR}/${FRAMEWORK_NAME}.xcframework"

# Remove old framework
rm -rf "${XCFRAMEWORK_PATH}"

xcodebuild -create-xcframework \
    -library "./target/aarch64-apple-ios/release/lib${RUST_LIB_NAME}.a" \
    -headers "${HEADER_DIR}" \
    -library "./target/aarch64-apple-ios-sim/release/lib${RUST_LIB_NAME}.a" \
    -headers "${HEADER_DIR}" \
    -library "./target/aarch64-apple-darwin/release/lib${RUST_LIB_NAME}.a" \
    -headers "${HEADER_DIR}" \
    -output "${XCFRAMEWORK_PATH}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create XCFramework${NC}"
    exit 1
fi

# Copy Swift binding files
echo -e "${YELLOW}Copying Swift binding files...${NC}"
cp "${BINDINGS_DIR}/${RUST_LIB_NAME}.swift" "${OUTPUT_DIR}/Utils/NostrFFI.swift"

echo -e "${GREEN}✅ Build completed!${NC}"
echo -e "${GREEN}📦 XCFramework: ${XCFRAMEWORK_PATH}${NC}"
echo -e "${GREEN}📄 Swift bindings: ${OUTPUT_DIR}/Utils/NostrFFI.swift${NC}"

echo -e "${BLUE}Now you can:${NC}"
echo -e "1. Drag ${FRAMEWORK_NAME}.xcframework into your Xcode project"
echo -e "2. Import NostrFFI module in your Swift code"
echo -e "3. Use createNostrClient() to create client instances"

# Clean up temporary files
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${BINDINGS_DIR}"

echo -e "${GREEN}🎉 All done!${NC}" 