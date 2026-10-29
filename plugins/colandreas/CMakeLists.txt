cmake_minimum_required(VERSION 3.19)
project(colandreas LANGUAGES C CXX VERSION 1.5.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED OMP_ROOT)
    message(FATAL_ERROR "pass -DOMP_ROOT=<open.mp checkout>")
endif()
if(NOT DEFINED BULLET_ROOT)
    message(FATAL_ERROR "pass -DBULLET_ROOT=<Bullet 2.82 static install>")
endif()

add_subdirectory(${OMP_ROOT}/SDK ${CMAKE_BINARY_DIR}/sdk)

add_library(${PROJECT_NAME} SHARED
    src/component.cpp
    src/Natives.cpp
    src/DynamicWorld.cpp
    src/ColObject.cpp
    src/ColAndreasDatabaseReader.cpp
    src/renderware.cpp
    src/dffread.cpp
)

target_include_directories(${PROJECT_NAME} PRIVATE
    ${OMP_ROOT}/lib
    ${OMP_ROOT}/lib/pawn/source
    ${OMP_ROOT}/lib/pawn/source/linux
    ${BULLET_ROOT}/include/bullet
    include
    src
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
    HAVE_STDINT_H=1
    PAWN_CELL_SIZE=32
    LINUX
    CA_VERSION="v1.5.0"
    CA_DATABASE_VERSION=2
)

target_compile_options(${PROJECT_NAME} PRIVATE -Wno-writable-strings -Wno-write-strings -Wno-unknown-pragmas)

set_target_properties(${PROJECT_NAME} PROPERTIES PREFIX "" OUTPUT_NAME "colandreas" SUFFIX ".so")

target_link_libraries(${PROJECT_NAME} PRIVATE
    OMP-SDK
    ${BULLET_ROOT}/lib/libBulletDynamics.a
    ${BULLET_ROOT}/lib/libBulletCollision.a
    ${BULLET_ROOT}/lib/libLinearMath.a
    -static-libstdc++
    -static-libgcc
)
