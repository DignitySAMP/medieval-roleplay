cmake_minimum_required(VERSION 3.19)
project(paths LANGUAGES C CXX VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED OMP_ROOT)
    message(FATAL_ERROR "pass -DOMP_ROOT=<open.mp checkout>")
endif()

add_subdirectory(${OMP_ROOT}/SDK ${CMAKE_BINARY_DIR}/sdk)

include_directories(
    ${OMP_ROOT}/lib
    ${OMP_ROOT}/lib/pawn/source
    ${OMP_ROOT}/lib/pawn/source/linux
    include
    src
)

add_definitions(
    -DHAVE_STDINT_H=1
    -DPAWN_CELL_SIZE=32
)

find_package(Threads REQUIRED)

add_library(${PROJECT_NAME} SHARED
    src/main.cpp
    src/natives.cpp
    src/node-graph.cpp
    src/paths-component.cpp
)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "" OUTPUT_NAME "paths" SUFFIX ".so")

target_link_libraries(${PROJECT_NAME} PRIVATE
    OMP-SDK
    Threads::Threads
    -static-libstdc++
    -static-libgcc
)
