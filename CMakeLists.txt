cmake_minimum_required(VERSION 2.8.4)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_SOURCE_DIR}/cmake/Pidbuhich.cmake)
set(CMAKE_CXX_STANDARD 17)
set(PROJECT_NAME Pidbuhich)
set(${PROJECT_NAME}_BOARD nano)
set(ARDUINO_CPU atmega328old)

project(${PROJECT_NAME})
set(SRC_DIR ${CMAKE_SOURCE_DIR}/src)
link_directories(${CMAKE_CURRENT_SOURCE_DIR}/${SRC_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/${ARDUINO_LIBRARIES_PATH})
set(${PROJECT_NAME}_SKETCH Pidbuhich.ino)
set(${PROJECT_NAME}_PORT COM3)

generate_arduino_firmware(${PROJECT_NAME})


print_board_list()
print_programmer_list()
