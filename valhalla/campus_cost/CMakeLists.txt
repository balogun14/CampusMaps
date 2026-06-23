cmake_minimum_required(VERSION 3.16)
project(campus_pedestrian VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Find Valhalla headers (expected from Docker build context)
find_path(VALHALLA_INCLUDE_DIR
    NAMES "valhalla/valhalla.h"
    PATHS /usr/local/include /usr/include
)

# Find Valhalla libraries
find_library(VALHALLA_BALDR_LIB
    NAMES valhalla_baldr
    PATHS /usr/local/lib /usr/lib
)
find_library(VALHALLA_SIF_LIB
    NAMES valhalla_sif
    PATHS /usr/local/lib /usr/lib
)

add_library(campus_pedestrian SHARED
    campus_pedestrian.cc
    campus_pedestrian.h
)

target_include_directories(campus_pedestrian
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE ${VALHALLA_INCLUDE_DIR}
)

target_link_libraries(campus_pedestrian
    PRIVATE ${VALHALLA_BALDR_LIB} ${VALHALLA_SIF_LIB}
)

# Install to standard location
install(TARGETS campus_pedestrian
    LIBRARY DESTINATION lib
)
