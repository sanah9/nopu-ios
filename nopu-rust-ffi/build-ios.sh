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

# Use our built-in uniffi-bindgen binary to generate bindings
echo "Generating Swift bindings with built-in tool..."
cargo run --bin uniffi-bindgen -- generate --library target/debug/libnopu_rust_ffi.dylib --language swift --out-dir "${BINDINGS_DIR}"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to generate Swift bindings${NC}"
    exit 1
fi

# Prepare header files
echo -e "${YELLOW}Preparing header files...${NC}"
HEADER_DIR="${BINDINGS_DIR}/include"
mkdir -p "${HEADER_DIR}"

# Copy and rename files
cp "${BINDINGS_DIR}/nopu_ffiFFI.h" "${HEADER_DIR}/"
cp "${BINDINGS_DIR}/nopu_ffiFFI.modulemap" "${HEADER_DIR}/module.modulemap"

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

# Keep Swift binding files in the Rust project directory
echo -e "${YELLOW}Organizing Swift binding files...${NC}"
cp "${BINDINGS_DIR}/nopu_ffi.swift" "./NostrFFI.swift"
cp "${BINDINGS_DIR}/nopu_ffiFFI.h" "./include/"
cp "${BINDINGS_DIR}/nopu_ffiFFI.modulemap" "./include/"

echo -e "${GREEN}✅ Build completed!${NC}"
echo -e "${GREEN}📦 XCFramework: ${XCFRAMEWORK_PATH}${NC}"
echo -e "${GREEN}📄 Swift bindings: ./NostrFFI.swift${NC}"
echo -e "${GREEN}📄 C header: ./include/nopu_ffiFFI.h${NC}"
echo -e "${GREEN}📄 Module map: ./include/nopu_ffiFFI.modulemap${NC}"

echo -e "${BLUE}To use in your iOS project:${NC}"
echo -e "1. Drag ${FRAMEWORK_NAME}.xcframework into your Xcode project"
echo -e "2. Copy NostrFFI.swift to your Swift project"
echo -e "3. Import the framework and use the generated Swift APIs"

# Clean up temporary files
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf "${BINDINGS_DIR}"

# Copy NostrFFI.swift to utils directory
echo -e "${YELLOW}Copying NostrFFI.swift to utils directory...${NC}"
cp "./NostrFFI.swift" "../nopu/Utils/"

echo -e "${GREEN}🎉 All done!${NC}" 