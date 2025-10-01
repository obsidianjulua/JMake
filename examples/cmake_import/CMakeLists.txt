cmake_minimum_required(VERSION 3.10)

project(MyCoolLibrary)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Library target
add_library(mycoollib SHARED
    src/math_functions.cpp
    src/string_utils.cpp
)

target_include_directories(mycoollib PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_options(mycoollib PRIVATE
    -O2
    -Wall
    -fPIC
)

target_compile_definitions(mycoollib PRIVATE
    VERSION=1.0
    FEATURE_ENABLED=1
)

target_link_libraries(mycoollib
    pthread
    m
)

# Optional: Executable target
add_executable(demo
    src/demo.cpp
)

target_link_libraries(demo
    mycoollib
)
