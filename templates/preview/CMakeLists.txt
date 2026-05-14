cmake_minimum_required(VERSION 3.16 FATAL_ERROR)
project(preview_gdml CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Geant4 REQUIRED gdml vis_all)
include(${Geant4_USE_FILE})

add_executable(preview_gdml main.cc)
target_link_libraries(preview_gdml ${Geant4_LIBRARIES})
