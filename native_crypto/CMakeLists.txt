# Specifies the minimum version of CMake required to build this project.
cmake_minimum_required(VERSION 3.14)

# Defines the project name and specifies the programming languages used (C in this case).
project(native_crypto LANGUAGES C)

# Includes the FetchContent module, which allows for managing external dependencies.
include(FetchContent)

# Declares the BoringSSL dependency.
FetchContent_Declare(
        boringssl # Name of the dependency.
        GIT_REPOSITORY https://boringssl.googlesource.com/boringssl # URL of the Git repository.
        GIT_TAG main # Git branch or tag to use (main branch in this case).
        GIT_SHALLOW TRUE # Performs a shallow clone (downloads only the latest commit).
)

# Makes the BoringSSL dependency available for use in the project.
# This will download and build BoringSSL if it hasn't been already.
FetchContent_MakeAvailable(boringssl)

# Sets the C++ standard to C++11 if no standard is already set and the compiler is Clang or GNU.
if(NOT CMAKE_CXX_STANDARD AND CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    set(CMAKE_CXX_STANDARD 11) # Sets C++ standard to 11.
    set(CMAKE_CXX_STANDARD_REQUIRED ON) # Enforces the specified C++ standard.
endif()

# Sets the C standard to C11 if no standard is already set and the compiler is Clang or GNU.
if(NOT CMAKE_C_STANDARD AND CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
    set(CMAKE_C_STANDARD 11) # Sets C standard to 11.
    set(CMAKE_C_STANDARD_REQUIRED ON) # Enforces the specified C standard.
endif()

# Adds include directories for the compiler to find header files.
include_directories(
        include # Project's local include directory.
        ${boringssl_SOURCE_DIR}/include # BoringSSL's include directory.
)

# Adds a shared library target named "native_crypto" built from the specified source file.
add_library(native_crypto SHARED src/crypto.c)

# Links the "native_crypto" library with BoringSSL's crypto and ssl libraries.
# "PRIVATE" means these dependencies are only needed for building "native_crypto" itself
# and are not propagated to targets that link against "native_crypto".
target_link_libraries(native_crypto PRIVATE crypto ssl)