cmake_minimum_required(VERSION 3.19)
project(Actors LANGUAGES C CXX VERSION 1.5.8)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED OMP_ROOT)
    message(FATAL_ERROR "pass -DOMP_ROOT=<open.mp checkout>")
endif()

function(GroupSourcesByFolder target)
endfunction()

add_subdirectory(${OMP_ROOT}/SDK ${CMAKE_BINARY_DIR}/sdk)
add_subdirectory(${OMP_ROOT}/Shared/Network ${CMAKE_BINARY_DIR}/network)
add_subdirectory(${OMP_ROOT}/Shared/NetCode ${CMAKE_BINARY_DIR}/netcode)

add_library(${PROJECT_NAME} SHARED src/actors_main.cpp)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "" OUTPUT_NAME "Actors" SUFFIX ".so")

target_compile_definitions(${PROJECT_NAME} PRIVATE
    OMP_VERSION_MAJOR=1
    OMP_VERSION_MINOR=5
    OMP_VERSION_PATCH=8
    BUILD_NUMBER=3079
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    OMP-SDK
    OMP-NetCode
    -static-libstdc++
    -static-libgcc
)
