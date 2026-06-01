cmake_minimum_required(VERSION 3.20)
project(WeightedInstrFreq VERSION 1.0.0 LANGUAGES C CXX)

# ============================================
# Find LLVM
# ============================================
find_package(LLVM REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "LLVM_DIR: ${LLVM_DIR}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================
# macOS / Homebrew LLVM setup
# ============================================

# Use LLVM's own compiler (Homebrew LLVM)
set(CMAKE_C_COMPILER   "${LLVM_TOOLS_BINARY_DIR}/clang")
set(CMAKE_CXX_COMPILER "${LLVM_TOOLS_BINARY_DIR}/clang++")

# Get LLVM installation root
get_filename_component(LLVM_PREFIX "${LLVM_TOOLS_BINARY_DIR}" DIRECTORY)

# Use the active macOS SDK (found via xcrun) to avoid sysroot mismatches
if(APPLE)
    execute_process(
        COMMAND xcrun --show-sdk-path
        OUTPUT_VARIABLE MACOS_SDK_PATH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    if(MACOS_SDK_PATH)
        message(STATUS "macOS SDK: ${MACOS_SDK_PATH}")
        set(CMAKE_OSX_SYSROOT "${MACOS_SDK_PATH}")
    endif()
endif()

# Force use of libc++ (LLVM's C++ standard library on macOS)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")

# Add LLVM include dirs and definitions
include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# ============================================
# Create the pass plugin (shared library)
# ============================================

add_library(WeightedInstrFreqPass SHARED
    src/WeightedInstrFreq.cpp
)

# Only link the LLVM components we actually use
llvm_map_components_to_libnames(llvm_libs
    Core
    Support
    Passes
)

target_link_libraries(WeightedInstrFreqPass
    ${llvm_libs}
)

# Strip the "lib" prefix so the plugin loads as WeightedInstrFreqPass.dylib
set_target_properties(WeightedInstrFreqPass PROPERTIES
    PREFIX ""
    OUTPUT_NAME "WeightedInstrFreqPass"
)