cmake_minimum_required(VERSION 3.19)
project(pedestrians LANGUAGES C CXX VERSION 2.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED OMP_ROOT)
    message(FATAL_ERROR "pass -DOMP_ROOT=<open.mp checkout>")
endif()

add_subdirectory(${OMP_ROOT}/SDK ${CMAKE_BINARY_DIR}/sdk)

set(RN ${CMAKE_CURRENT_SOURCE_DIR}/third_party/recastnavigation)
file(GLOB DETOUR_SRC ${RN}/Detour/Source/*.cpp ${RN}/DetourCrowd/Source/*.cpp)

include_directories(
    ${RN}/Detour/Include
    ${RN}/DetourCrowd/Include
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

add_library(${PROJECT_NAME} SHARED src/component.cpp ${DETOUR_SRC})

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "" OUTPUT_NAME "pedestrians" SUFFIX ".so")

target_link_libraries(${PROJECT_NAME} PRIVATE
    OMP-SDK
    -static-libstdc++
    -static-libgcc
)
