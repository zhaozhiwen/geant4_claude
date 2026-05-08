cmake_minimum_required(VERSION 3.16 FATAL_ERROR)
project(geant4_claude_main CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Geant4 REQUIRED gdml ui_all vis_all)
find_package(ROOT   REQUIRED COMPONENTS Tree RIO)

include(${Geant4_USE_FILE})

add_executable(geant4_claude_main geant4_claude_main.cc)
target_include_directories(geant4_claude_main PRIVATE ${ROOT_INCLUDE_DIRS})
target_link_libraries(geant4_claude_main
  ${Geant4_LIBRARIES}
  ROOT::Core ROOT::RIO ROOT::Tree)
