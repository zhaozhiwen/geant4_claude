cmake_minimum_required(VERSION 3.16 FATAL_ERROR)
project(g4c_optical_fixture CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Geant4 REQUIRED gdml ui_all vis_all)
find_package(ROOT   REQUIRED COMPONENTS Tree RIO)

include(${Geant4_USE_FILE})

add_executable(g4c_optical_fixture main.cc)
target_include_directories(g4c_optical_fixture PRIVATE ${ROOT_INCLUDE_DIRS})
target_link_libraries(g4c_optical_fixture
  ${Geant4_LIBRARIES}
  ROOT::Core ROOT::RIO ROOT::Tree)
