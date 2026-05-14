cmake_minimum_required(VERSION 3.16 FATAL_ERROR)
project(validate_gdml CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Geant4 REQUIRED gdml)
include(${Geant4_USE_FILE})

add_executable(validate_gdml main.cc)
target_link_libraries(validate_gdml ${Geant4_LIBRARIES})
