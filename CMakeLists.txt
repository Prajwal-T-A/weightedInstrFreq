cmake_minimum_required(VERSION 3.20)
project(WeightedInstrFreq VERSION 1.0.0 LANGUAGES C CXX)

# Find LLVM
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "LLVM_DIR: ${LLVM_DIR}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================
# CRITICAL FIX: macOS SDK + Homebrew LLVM
# ============================================

# Use LLVM's own compiler
set(CMAKE_C_COMPILER "${LLVM_TOOLS_BINARY_DIR}/clang")
set(CMAKE_CXX_COMPILER "${LLVM_TOOLS_BINARY_DIR}/clang++")

# Get LLVM installation root
get_filename_component(LLVM_PREFIX "${LLVM_TOOLS_BINARY_DIR}" DIRECTORY)

# CRITICAL: Add LLVM's libc++ headers BEFORE anything else
# This prevents Xcode SDK headers from conflicting
include_directories(BEFORE SYSTEM
    "${LLVM_PREFIX}/include/c++/v1"
)

# Add LLVM's clang builtin headers (for stddef.h, etc.)
include_directories(BEFORE SYSTEM
    "${LLVM_PREFIX}/lib/clang/${LLVM_PACKAGE_VERSION}/include"
)

# Add LLVM main include directory
include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# Force use of libc++ and tell clang where its headers are
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")

# ============================================
# Create the pass plugin
# ============================================

add_library(WeightedInstrFreqPass SHARED
    src/WeightedInstrFreq.cpp
)

# Use modern LLVM component linking
llvm_map_components_to_libnames(llvm_libs 
    Core 
    Support 
    Passes
)

target_link_libraries(WeightedInstrFreqPass
    ${llvm_libs}
)

set_target_properties(WeightedInstrFreqPass PROPERTIES
    PREFIX ""
    OUTPUT_NAME "WeightedInstrFreqPass"
)