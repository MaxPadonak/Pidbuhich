cmake_minimum_required(VERSION 2.8.5)
include(CMakeParseArguments)

function(PRINT_BOARD_LIST)
    foreach(PLATFORM ${ARDUINO_PLATFORMS})
        if(${PLATFORM}_BOARDS)
            message(STATUS "${PLATFORM} Boards:")
            print_list(${PLATFORM}_BOARDS)
            message(STATUS "")
        endif()
    endforeach()
endfunction()

function(PRINT_PROGRAMMER_LIST)
    foreach(PLATFORM ${ARDUINO_PLATFORMS})
        if(${PLATFORM}_PROGRAMMERS)
            message(STATUS "${PLATFORM} Programmers:")
            print_list(${PLATFORM}_PROGRAMMERS)
        endif()
        message(STATUS "")
    endforeach()
endfunction()

function(PRINT_PROGRAMMER_SETTINGS PROGRAMMER)
    if(${PROGRAMMER}.SETTINGS)
        message(STATUS "Programmer ${PROGRAMMER} Settings:")
        print_settings(${PROGRAMMER})
    endif()
endfunction()

function(PRINT_BOARD_SETTINGS ARDUINO_BOARD)
    if(${ARDUINO_BOARD}.SETTINGS)
        message(STATUS "Arduino ${ARDUINO_BOARD} Board:")
        print_settings(${ARDUINO_BOARD})
    endif()
endfunction()

function(GENERATE_ARDUINO_LIBRARY INPUT_NAME)
    message(STATUS "Generating ${INPUT_NAME}")
    parse_generator_arguments(${INPUT_NAME} INPUT
            "NO_AUTOLIBS;MANUAL"                  # Options
            "BOARD"                               # One Value Keywords
            "SRCS;HDRS;LIBS"                      # Multi Value Keywords
            ${ARGN})

    if(NOT INPUT_BOARD)
        set(INPUT_BOARD ${ARDUINO_DEFAULT_BOARD})
    endif()
    if(NOT INPUT_MANUAL)
        set(INPUT_MANUAL FALSE)
    endif()
    required_variables(VARS INPUT_SRCS INPUT_BOARD MSG "must define for target ${INPUT_NAME}")

    set(ALL_LIBS)
    set(ALL_SRCS ${INPUT_SRCS} ${INPUT_HDRS})

    if(NOT INPUT_MANUAL)
        setup_arduino_core(CORE_LIB ${INPUT_BOARD})
    endif()

    find_arduino_libraries(TARGET_LIBS "${ALL_SRCS}" "")
    set(LIB_DEP_INCLUDES)
    foreach(LIB_DEP ${TARGET_LIBS})
        set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${LIB_DEP}\"")
    endforeach()

    if(NOT ${INPUT_NO_AUTOLIBS})
        setup_arduino_libraries(ALL_LIBS  ${INPUT_BOARD} "${ALL_SRCS}" "" "${LIB_DEP_INCLUDES}" "")
    endif()

    list(APPEND ALL_LIBS ${CORE_LIB} ${INPUT_LIBS})

    add_library(${INPUT_NAME} ${ALL_SRCS})

    get_arduino_flags(ARDUINO_COMPILE_FLAGS ARDUINO_LINK_FLAGS  ${INPUT_BOARD} ${INPUT_MANUAL})

    set_target_properties(${INPUT_NAME} PROPERTIES
            COMPILE_FLAGS "${ARDUINO_COMPILE_FLAGS} ${COMPILE_FLAGS} ${LIB_DEP_INCLUDES}"
            LINK_FLAGS "${ARDUINO_LINK_FLAGS} ${LINK_FLAGS}")

    target_link_libraries(${INPUT_NAME} ${ALL_LIBS} "-lc -lm")
endfunction()

function(GENERATE_AVR_LIBRARY INPUT_NAME)
    message(STATUS "Generating ${INPUT_NAME}")
    parse_generator_arguments(${INPUT_NAME} INPUT
            "NO_AUTOLIBS;MANUAL"                  # Options
            "BOARD"                               # One Value Keywords
            "SRCS;HDRS;LIBS"                      # Multi Value Keywords
            ${ARGN})

    if(NOT INPUT_BOARD)
        set(INPUT_BOARD ${ARDUINO_DEFAULT_BOARD})
    endif()

    required_variables(VARS INPUT_SRCS INPUT_BOARD MSG "must define for target ${INPUT_NAME}")

    if(INPUT_HDRS)
        set( INPUT_HDRS "SRCS ${INPUT_HDRS}" )
    endif()
    if(INPUT_LIBS)
        set( INPUT_LIBS "LIBS ${INPUT_LIBS}" )
    endif()

    if(INPUT_HDRS)
        list(INSERT INPUT_HDRS 0 "HDRS")
    endif()
    if(INPUT_LIBS)
        list(INSERT INPUT_LIBS 0 "LIBS")
    endif()
    generate_arduino_library( ${INPUT_NAME}
            NO_AUTOLIBS
            MANUAL
            BOARD ${INPUT_BOARD}
            SRCS ${INPUT_SRCS}
            ${INPUT_HDRS}
            ${INPUT_LIBS} )

endfunction()

function(GENERATE_ARDUINO_FIRMWARE INPUT_NAME)
    message(STATUS "Generating ${INPUT_NAME}")
    parse_generator_arguments(${INPUT_NAME} INPUT
            "NO_AUTOLIBS;MANUAL"                  # Options
            "BOARD;PORT;SKETCH;PROGRAMMER"        # One Value Keywords
            "SERIAL;SRCS;HDRS;LIBS;ARDLIBS;AFLAGS"  # Multi Value Keywords
            ${ARGN})

    if(NOT INPUT_BOARD)
        set(INPUT_BOARD ${ARDUINO_DEFAULT_BOARD})
    endif()
    if(NOT INPUT_PORT)
        set(INPUT_PORT ${ARDUINO_DEFAULT_PORT})
    endif()
    if(NOT INPUT_SERIAL)
        set(INPUT_SERIAL ${ARDUINO_DEFAULT_SERIAL})
    endif()
    if(NOT INPUT_PROGRAMMER)
        set(INPUT_PROGRAMMER ${ARDUINO_DEFAULT_PROGRAMMER})
    endif()
    if(NOT INPUT_MANUAL)
        set(INPUT_MANUAL FALSE)
    endif()
    required_variables(VARS INPUT_BOARD MSG "must define for target ${INPUT_NAME}")

    set(ALL_LIBS)
    set(ALL_SRCS ${INPUT_SRCS} ${INPUT_HDRS})
    set(LIB_DEP_INCLUDES)

    if(NOT INPUT_MANUAL)
        setup_arduino_core(CORE_LIB ${INPUT_BOARD})
    endif()

    if(NOT "${INPUT_SKETCH}" STREQUAL "")
        get_filename_component(INPUT_SKETCH "${INPUT_SKETCH}" ABSOLUTE)
        setup_arduino_sketch(${INPUT_NAME} ${INPUT_SKETCH} ALL_SRCS)
        if (IS_DIRECTORY "${INPUT_SKETCH}")
            set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${INPUT_SKETCH}\"")
        else()
            get_filename_component(INPUT_SKETCH_PATH "${INPUT_SKETCH}" PATH)
            set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${INPUT_SKETCH_PATH}\"")
        endif()
    endif()

    required_variables(VARS ALL_SRCS MSG "must define SRCS or SKETCH for target ${INPUT_NAME}")

    find_arduino_libraries(TARGET_LIBS "${ALL_SRCS}" "${INPUT_ARDLIBS}")
    foreach(LIB_DEP ${TARGET_LIBS})
        arduino_debug_msg("Arduino Library: ${LIB_DEP}")
        set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${LIB_DEP}\" -I\"${LIB_DEP}/src\"")
    endforeach()

    if(NOT INPUT_NO_AUTOLIBS)
        setup_arduino_libraries(ALL_LIBS  ${INPUT_BOARD} "${ALL_SRCS}" "${INPUT_ARDLIBS}" "${LIB_DEP_INCLUDES}" "")
        foreach(LIB_INCLUDES ${ALL_LIBS_INCLUDES})
            arduino_debug_msg("Arduino Library Includes: ${LIB_INCLUDES}")
            set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} ${LIB_INCLUDES}")
        endforeach()
    endif()

    list(APPEND ALL_LIBS ${CORE_LIB} ${INPUT_LIBS})

    setup_arduino_target(${INPUT_NAME} ${INPUT_BOARD} "${ALL_SRCS}" "${ALL_LIBS}" "${LIB_DEP_INCLUDES}" "" "${INPUT_MANUAL}")

    if(INPUT_PORT)
        setup_arduino_upload(${INPUT_BOARD} ${INPUT_NAME} ${INPUT_PORT} "${INPUT_PROGRAMMER}" "${INPUT_AFLAGS}")
    endif()

    if(INPUT_SERIAL)
        setup_serial_target(${INPUT_NAME} "${INPUT_SERIAL}" "${INPUT_PORT}")
    endif()

endfunction()

function(GENERATE_AVR_FIRMWARE INPUT_NAME)
    # TODO: This is not optimal!!!!
    message(STATUS "Generating ${INPUT_NAME}")
    parse_generator_arguments(${INPUT_NAME} INPUT
            "NO_AUTOLIBS;MANUAL"            # Options
            "BOARD;PORT;PROGRAMMER"  # One Value Keywords
            "SERIAL;SRCS;HDRS;LIBS;AFLAGS"  # Multi Value Keywords
            ${ARGN})

    if(NOT INPUT_BOARD)
        set(INPUT_BOARD ${ARDUINO_DEFAULT_BOARD})
    endif()
    if(NOT INPUT_PORT)
        set(INPUT_PORT ${ARDUINO_DEFAULT_PORT})
    endif()
    if(NOT INPUT_SERIAL)
        set(INPUT_SERIAL ${ARDUINO_DEFAULT_SERIAL})
    endif()
    if(NOT INPUT_PROGRAMMER)
        set(INPUT_PROGRAMMER ${ARDUINO_DEFAULT_PROGRAMMER})
    endif()

    required_variables(VARS INPUT_BOARD INPUT_SRCS MSG "must define for target ${INPUT_NAME}")

    if(INPUT_HDRS)
        list(INSERT INPUT_HDRS 0 "HDRS")
    endif()
    if(INPUT_LIBS)
        list(INSERT INPUT_LIBS 0 "LIBS")
    endif()
    if(INPUT_AFLAGS)
        list(INSERT INPUT_AFLAGS 0 "AFLAGS")
    endif()

    generate_arduino_firmware( ${INPUT_NAME}
            NO_AUTOLIBS
            MANUAL
            BOARD ${INPUT_BOARD}
            PORT ${INPUT_PORT}
            PROGRAMMER ${INPUT_PROGRAMMER}
            SERIAL ${INPUT_SERIAL}
            SRCS ${INPUT_SRCS}
            ${INPUT_HDRS}
            ${INPUT_LIBS}
            ${INPUT_AFLAGS} )

endfunction()

function(GENERATE_ARDUINO_EXAMPLE INPUT_NAME)
    parse_generator_arguments(${INPUT_NAME} INPUT
            ""                                       # Options
            "LIBRARY;EXAMPLE;BOARD;PORT;PROGRAMMER"  # One Value Keywords
            "SERIAL;AFLAGS"                          # Multi Value Keywords
            ${ARGN})


    if(NOT INPUT_BOARD)
        set(INPUT_BOARD ${ARDUINO_DEFAULT_BOARD})
    endif()
    if(NOT INPUT_PORT)
        set(INPUT_PORT ${ARDUINO_DEFAULT_PORT})
    endif()
    if(NOT INPUT_SERIAL)
        set(INPUT_SERIAL ${ARDUINO_DEFAULT_SERIAL})
    endif()
    if(NOT INPUT_PROGRAMMER)
        set(INPUT_PROGRAMMER ${ARDUINO_DEFAULT_PROGRAMMER})
    endif()
    required_variables(VARS INPUT_LIBRARY INPUT_EXAMPLE INPUT_BOARD
            MSG "must define for target ${INPUT_NAME}")

    message(STATUS "Generating ${INPUT_NAME}")

    set(ALL_LIBS)
    set(ALL_SRCS)

    setup_arduino_core(CORE_LIB ${INPUT_BOARD})

    setup_arduino_example("${INPUT_NAME}" "${INPUT_LIBRARY}" "${INPUT_EXAMPLE}" ALL_SRCS)

    if(NOT ALL_SRCS)
        message(FATAL_ERROR "Missing sources for example, aborting!")
    endif()

    find_arduino_libraries(TARGET_LIBS "${ALL_SRCS}" "")
    set(LIB_DEP_INCLUDES)
    foreach(LIB_DEP ${TARGET_LIBS})
        set(LIB_DEP_INCLUDES "${LIB_DEP_INCLUDES} -I\"${LIB_DEP}\"")
    endforeach()

    setup_arduino_libraries(ALL_LIBS ${INPUT_BOARD} "${ALL_SRCS}" "" "${LIB_DEP_INCLUDES}" "")

    list(APPEND ALL_LIBS ${CORE_LIB} ${INPUT_LIBS})

    setup_arduino_target(${INPUT_NAME} ${INPUT_BOARD}  "${ALL_SRCS}" "${ALL_LIBS}" "${LIB_DEP_INCLUDES}" "" FALSE)

    if(INPUT_PORT)
        setup_arduino_upload(${INPUT_BOARD} ${INPUT_NAME} ${INPUT_PORT} "${INPUT_PROGRAMMER}" "${INPUT_AFLAGS}")
    endif()

    if(INPUT_SERIAL)
        setup_serial_target(${INPUT_NAME} "${INPUT_SERIAL}" "${INPUT_PORT}")
    endif()
endfunction()

function(REGISTER_HARDWARE_PLATFORM PLATFORM_PATH)
    string(REGEX REPLACE "/$" "" PLATFORM_PATH ${PLATFORM_PATH})
    GET_FILENAME_COMPONENT(PLATFORM ${PLATFORM_PATH} NAME)

    if(PLATFORM)
        string(TOUPPER ${PLATFORM} PLATFORM)
        list(FIND ARDUINO_PLATFORMS ${PLATFORM} platform_exists)

        if (platform_exists EQUAL -1)
            set(${PLATFORM}_PLATFORM_PATH ${PLATFORM_PATH} CACHE INTERNAL "The path to ${PLATFORM}")
            set(ARDUINO_PLATFORMS ${ARDUINO_PLATFORMS} ${PLATFORM} CACHE INTERNAL "A list of registered platforms")

            find_file(${PLATFORM}_CORES_PATH
                    NAMES cores
                    PATHS ${PLATFORM_PATH}
                    DOC "Path to directory containing the Arduino core sources."
                    NO_SYSTEM_ENVIRONMENT_PATH)

            find_file(${PLATFORM}_VARIANTS_PATH
                    NAMES variants
                    PATHS ${PLATFORM_PATH}
                    DOC "Path to directory containing the Arduino variant sources."
                    NO_SYSTEM_ENVIRONMENT_PATH)

            find_file(${PLATFORM}_BOOTLOADERS_PATH
                    NAMES bootloaders
                    PATHS ${PLATFORM_PATH}
                    DOC "Path to directory containing the Arduino bootloader images and sources."
                    NO_SYSTEM_ENVIRONMENT_PATH)

            find_file(${PLATFORM}_LIBRARIES_PATH
                    NAMES libraries
                    PATHS ${PLATFORM_PATH}
                    DOC "Path to directory containing the Arduino hardware libraries sources."
                    NO_SYSTEM_ENVIRONMENT_PATH)

            find_file(${PLATFORM}_PROGRAMMERS_PATH
                    NAMES programmers.txt
                    PATHS ${PLATFORM_PATH}
                    DOC "Path to Arduino programmers definition file."
                    NO_SYSTEM_ENVIRONMENT_PATH)

            find_file(${PLATFORM}_BOARDS_PATH
                    NAMES boards.txt
                    PATHS ${PLATFORM_PATH}
                    DOC "Path to Arduino boards definition file."
                    NO_SYSTEM_ENVIRONMENT_PATH)

            if(${PLATFORM}_BOARDS_PATH)
                load_arduino_style_settings(${PLATFORM}_BOARDS "${PLATFORM_PATH}/boards.txt")
            endif()

            if(${PLATFORM}_PROGRAMMERS_PATH)
                # load_arduino_style_settings(${PLATFORM}_PROGRAMMERS "${ARDUINO_PROGRAMMERS_PATH}")
                load_arduino_style_settings(${PLATFORM}_PROGRAMMERS "${PLATFORM_PATH}/programmers.txt")
            endif()

            if(${PLATFORM}_VARIANTS_PATH)
                file(GLOB sub-dir ${${PLATFORM}_VARIANTS_PATH}/*)
                foreach(dir ${sub-dir})
                    if(IS_DIRECTORY ${dir})
                        get_filename_component(variant ${dir} NAME)
                        set(VARIANTS ${VARIANTS} ${variant} CACHE INTERNAL "A list of registered variant boards")
                        set(${variant}.path ${dir} CACHE INTERNAL "The path to the variant ${variant}")
                    endif()
                endforeach()
            endif()

            if(${PLATFORM}_CORES_PATH)
                file(GLOB sub-dir ${${PLATFORM}_CORES_PATH}/*)
                foreach(dir ${sub-dir})
                    if(IS_DIRECTORY ${dir})
                        get_filename_component(core ${dir} NAME)
                        set(CORES ${CORES} ${core} CACHE INTERNAL "A list of registered cores")
                        set(${core}.path ${dir} CACHE INTERNAL "The path to the core ${core}")
                    endif()
                endforeach()
            endif()

        endif()
    endif()

endfunction()

macro(PARSE_GENERATOR_ARGUMENTS TARGET_NAME PREFIX OPTIONS ARGS MULTI_ARGS)
    cmake_parse_arguments(${PREFIX} "${OPTIONS}" "${ARGS}" "${MULTI_ARGS}" ${ARGN})
    error_for_unparsed(${PREFIX})
    load_generator_settings(${TARGET_NAME} ${PREFIX} ${OPTIONS} ${ARGS} ${MULTI_ARGS})
endmacro()

function(LOAD_GENERATOR_SETTINGS TARGET_NAME PREFIX)
    foreach(GEN_SUFFIX ${ARGN})
        if(${TARGET_NAME}_${GEN_SUFFIX} AND NOT ${PREFIX}_${GEN_SUFFIX})
            set(${PREFIX}_${GEN_SUFFIX} ${${TARGET_NAME}_${GEN_SUFFIX}} PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

function(get_arduino_flags COMPILE_FLAGS_VAR LINK_FLAGS_VAR BOARD_ID MANUAL)

    set(BOARD_CORE ${${BOARD_ID}.build.core})
    if(BOARD_CORE)
        if(ARDUINO_SDK_VERSION MATCHES "([0-9]+)[.]([0-9]+)[.]([0-9]+)")
            string(REPLACE "." "" ARDUINO_VERSION_DEFINE "${ARDUINO_SDK_VERSION}") # Normalize version (remove all periods)
            set(ARDUINO_VERSION_DEFINE "")
            if(CMAKE_MATCH_1 GREATER 0)
                set(ARDUINO_VERSION_DEFINE "${CMAKE_MATCH_1}")
            endif()
            if(CMAKE_MATCH_2 GREATER 10)
                set(ARDUINO_VERSION_DEFINE "${ARDUINO_VERSION_DEFINE}${CMAKE_MATCH_2}")
            else()
                set(ARDUINO_VERSION_DEFINE "${ARDUINO_VERSION_DEFINE}0${CMAKE_MATCH_2}")
            endif()
            if(CMAKE_MATCH_3 GREATER 10)
                set(ARDUINO_VERSION_DEFINE "${ARDUINO_VERSION_DEFINE}${CMAKE_MATCH_3}")
            else()
                set(ARDUINO_VERSION_DEFINE "${ARDUINO_VERSION_DEFINE}0${CMAKE_MATCH_3}")
            endif()
        else()
            message("Invalid Arduino SDK Version (${ARDUINO_SDK_VERSION})")
        endif()

        # output
        set(COMPILE_FLAGS "")

        if(${BOARD_ID}${ARDUINO_CPUMENU}.build.f_cpu)
            set(COMPILE_FLAGS "${COMPILE_FLAGS} -DF_CPU=${${BOARD_ID}${ARDUINO_CPUMENU}.build.f_cpu}")
        else()
            if(${BOARD_ID}.build.f_cpu)
                set(COMPILE_FLAGS "${COMPILE_FLAGS} -DF_CPU=${${BOARD_ID}.build.f_cpu}")
            else()
                message(FATAL_ERROR "Can not find f_cpu in boards.txt for Arduino board ID (${BOARD_ID}), aborting.")
            endif()
        endif()

        set(COMPILE_FLAGS "${COMPILE_FLAGS} -DARDUINO=${ARDUINO_VERSION_DEFINE} -DARDUINO_${${BOARD_ID}.build.board} -DARDUINO_ARCH_AVR -mmcu=${${BOARD_ID}${ARDUINO_CPUMENU}.build.mcu}")

        if(DEFINED ${BOARD_ID}.build.vid)
            set(COMPILE_FLAGS "${COMPILE_FLAGS} -DUSB_VID=${${BOARD_ID}.build.vid}")
        endif()
        if(DEFINED ${BOARD_ID}.build.pid)
            set(COMPILE_FLAGS "${COMPILE_FLAGS} -DUSB_PID=${${BOARD_ID}.build.pid}")
        endif()
        if(NOT MANUAL)
            set(COMPILE_FLAGS "${COMPILE_FLAGS} -I\"${${BOARD_CORE}.path}\" -I\"${ARDUINO_LIBRARIES_PATH}\"")
        endif()
        set(LINK_FLAGS "-mmcu=${${BOARD_ID}${ARDUINO_CPUMENU}.build.mcu}")
        if(ARDUINO_SDK_VERSION VERSION_GREATER 1.0 OR ARDUINO_SDK_VERSION VERSION_EQUAL 1.0)
            if(NOT MANUAL)
                set(PIN_HEADER ${${${BOARD_ID}.build.variant}.path})
                if(PIN_HEADER)
                    set(COMPILE_FLAGS "${COMPILE_FLAGS} -I\"${PIN_HEADER}\"")
                endif()
            endif()
        endif()

        # output
        set(${COMPILE_FLAGS_VAR} "${COMPILE_FLAGS}" PARENT_SCOPE)
        set(${LINK_FLAGS_VAR} "${LINK_FLAGS}" PARENT_SCOPE)

    else()
        message(FATAL_ERROR "Invalid Arduino board ID (${BOARD_ID}), aborting.")
    endif()
endfunction()

function(setup_arduino_core VAR_NAME BOARD_ID)
    set(CORE_LIB_NAME ${BOARD_ID}_CORE)
    set(BOARD_CORE ${${BOARD_ID}.build.core})
    if(BOARD_CORE)
        if(NOT TARGET ${CORE_LIB_NAME})
            set(BOARD_CORE_PATH ${${BOARD_CORE}.path})
            find_sources(CORE_SRCS ${BOARD_CORE_PATH} True)
            # Debian/Ubuntu fix
            list(REMOVE_ITEM CORE_SRCS "${BOARD_CORE_PATH}/main.cxx")
            add_library(${CORE_LIB_NAME} ${CORE_SRCS})
            get_arduino_flags(ARDUINO_COMPILE_FLAGS ARDUINO_LINK_FLAGS ${BOARD_ID} FALSE)
            set_target_properties(${CORE_LIB_NAME} PROPERTIES
                    COMPILE_FLAGS "${ARDUINO_COMPILE_FLAGS}"
                    LINK_FLAGS "${ARDUINO_LINK_FLAGS}")
        endif()
        set(${VAR_NAME} ${CORE_LIB_NAME} PARENT_SCOPE)
    endif()
endfunction()

function(find_arduino_libraries VAR_NAME SRCS ARDLIBS)
    get_property(include_dirs DIRECTORY . PROPERTY INCLUDE_DIRECTORIES)
    set(ARDUINO_LIBS )
    foreach(SRC ${SRCS})

        # Skipping generated files. They are, probably, not exist yet.
        # TODO: Maybe it's possible to skip only really nonexisting files,
        # but then it wiil be less deterministic.
        get_source_file_property(_srcfile_generated ${SRC} GENERATED)
        # Workaround for sketches, which are marked as generated
        get_source_file_property(_sketch_generated ${SRC} GENERATED_SKETCH)

        if(NOT ${_srcfile_generated} OR ${_sketch_generated})
            if(NOT (EXISTS ${SRC} OR
                    EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/${SRC} OR
                    EXISTS ${CMAKE_CURRENT_BINARY_DIR}/${SRC}))
                message(FATAL_ERROR "Invalid source file: ${SRC}")
            endif()
            file(STRINGS ${SRC} SRC_CONTENTS)

            foreach(LIBNAME ${ARDLIBS})
                list(APPEND SRC_CONTENTS "#include <${LIBNAME}.h>")
            endforeach()

            foreach(SRC_LINE ${SRC_CONTENTS})
                if("#${SRC_LINE}#" MATCHES "^#[ \t]*#[ \t]*include[ \t]*[<\"]([^>\"]*)[>\"]#")
                    get_filename_component(INCLUDE_NAME ${CMAKE_MATCH_1} NAME_WE)
                    get_property(LIBRARY_SEARCH_PATH
                            DIRECTORY     # Property Scope
                            PROPERTY LINK_DIRECTORIES)
                    foreach(LIB_SEARCH_PATH ${include_dirs} ${LIBRARY_SEARCH_PATH} ${ARDUINO_LIBRARIES_PATH} ${${ARDUINO_PLATFORM}_LIBRARIES_PATH} . ${CMAKE_CURRENT_SOURCE_DIR}/libraries ${ARDUINO_EXTRA_LIBRARIES_PATH})
                        if(EXISTS ${LIB_SEARCH_PATH}/${INCLUDE_NAME}/${CMAKE_MATCH_1})
                            list(APPEND ARDUINO_LIBS ${LIB_SEARCH_PATH}/${INCLUDE_NAME})
                            break()
                        endif()
                        if(EXISTS ${LIB_SEARCH_PATH}/${INCLUDE_NAME}/src/${CMAKE_MATCH_1})
                            list(APPEND ARDUINO_LIBS ${LIB_SEARCH_PATH}/${INCLUDE_NAME})
                            break()
                        endif()
                        get_source_file_property(_header_generated ${LIB_SEARCH_PATH}/${CMAKE_MATCH_1} GENERATED)
                        if((EXISTS ${LIB_SEARCH_PATH}/${CMAKE_MATCH_1}) OR ${_header_generated})
                            list(APPEND ARDUINO_LIBS ${LIB_SEARCH_PATH}/${INCLUDE_NAME})
                            break()
                        endif()
                    endforeach()
                endif()
            endforeach()
        endif()
    endforeach()
    if(ARDUINO_LIBS)
        list(REMOVE_DUPLICATES ARDUINO_LIBS)
    endif()
    set(${VAR_NAME} ${ARDUINO_LIBS} PARENT_SCOPE)
endfunction()

# For known libraries can list recurse here
set(Wire_RECURSE True)
set(Ethernet_RECURSE True)
set(SD_RECURSE True)
set(Servo_RECURSE True)
set(SPI_RECURSE True)
set(SoftwareSerial_RECURSE True)
set(EEPROM_RECURSE True)
set(LiquidCrystal_RECURSE True)
set(TFT_RECURSE True)
set(WiFi_RECURSE True)
set(Robot_Control_RECURSE True)
set(DFPlayer_Mini_Mp3_RECURSE True)
function(setup_arduino_library VAR_NAME BOARD_ID LIB_PATH COMPILE_FLAGS LINK_FLAGS)
    set(LIB_TARGETS)
    set(LIB_INCLUDES)

    get_filename_component(LIB_NAME ${LIB_PATH} NAME)
    set(TARGET_LIB_NAME ${BOARD_ID}_${LIB_NAME})
    if(NOT TARGET ${TARGET_LIB_NAME})
        string(REGEX REPLACE ".*/" "" LIB_SHORT_NAME ${LIB_NAME})

        # Detect if recursion is needed
        if (NOT DEFINED ${LIB_SHORT_NAME}_RECURSE)
            set(${LIB_SHORT_NAME}_RECURSE False)
        endif()
        find_sources(LIB_SRCS ${LIB_PATH} ${${LIB_SHORT_NAME}_RECURSE})
        if(LIB_SRCS)
            message(STATUS "Generating ${TARGET_LIB_NAME} for library ${LIB_NAME}")
            arduino_debug_msg("Generating Arduino ${LIB_NAME} library")
            add_library(${TARGET_LIB_NAME} STATIC ${LIB_SRCS})
            include_directories(${LIB_PATH})
            include_directories(${LIB_PATH}/src)
            include_directories(${LIB_PATH}/utility)

            get_arduino_flags(ARDUINO_COMPILE_FLAGS ARDUINO_LINK_FLAGS ${BOARD_ID} FALSE)

            find_arduino_libraries(LIB_DEPS "${LIB_SRCS}" "")

            foreach(LIB_DEP ${LIB_DEPS})
                if(NOT DEP_LIB_SRCS STREQUAL TARGET_LIB_NAME AND DEP_LIB_SRCS)
                    message(STATUS "Found library ${LIB_NAME} needs ${DEP_LIB_SRCS}")
                endif()

                setup_arduino_library(DEP_LIB_SRCS ${BOARD_ID} ${LIB_DEP} "${COMPILE_FLAGS}" "${LINK_FLAGS}")
                # Do not link to this library. DEP_LIB_SRCS will always be only one entry
                # if we are looking at the same library.
                if(NOT DEP_LIB_SRCS STREQUAL TARGET_LIB_NAME)
                    list(APPEND LIB_TARGETS ${DEP_LIB_SRCS})
                    list(APPEND LIB_INCLUDES ${DEP_LIB_SRCS_INCLUDES})
                endif()
            endforeach()

            if (LIB_INCLUDES)
                string(REPLACE ";" " " LIB_INCLUDES "${LIB_INCLUDES}")
            endif()

            set_target_properties(${TARGET_LIB_NAME} PROPERTIES
                    COMPILE_FLAGS "${ARDUINO_COMPILE_FLAGS} ${LIB_INCLUDES} -I\"${LIB_PATH}\" -I\"${LIB_PATH}/src\" -I\"${LIB_PATH}/utility\" ${COMPILE_FLAGS}"
                    LINK_FLAGS "${ARDUINO_LINK_FLAGS} ${LINK_FLAGS}")
            list(APPEND LIB_INCLUDES "-I\"${LIB_PATH}\" -I\"${LIB_PATH}/src\" -I\"${LIB_PATH}/utility\"")

            target_link_libraries(${TARGET_LIB_NAME} ${BOARD_ID}_CORE)
            list(APPEND LIB_TARGETS ${TARGET_LIB_NAME})

        endif()
    else()
        # Target already exists, skiping creating
        list(APPEND LIB_TARGETS ${TARGET_LIB_NAME})
    endif()
    if(LIB_TARGETS)
        list(REMOVE_DUPLICATES LIB_TARGETS)
    endif()
    set(${VAR_NAME}          ${LIB_TARGETS}  PARENT_SCOPE)
    set(${VAR_NAME}_INCLUDES ${LIB_INCLUDES} PARENT_SCOPE)
endfunction()

function(setup_arduino_libraries VAR_NAME BOARD_ID SRCS ARDLIBS COMPILE_FLAGS LINK_FLAGS)
    set(LIB_TARGETS)
    set(LIB_INCLUDES)

    find_arduino_libraries(TARGET_LIBS "${SRCS}" ARDLIBS)
    foreach(TARGET_LIB ${TARGET_LIBS})
        # Create static library instead of returning sources
        setup_arduino_library(LIB_DEPS ${BOARD_ID} ${TARGET_LIB} "${COMPILE_FLAGS}" "${LINK_FLAGS}")
        list(APPEND LIB_TARGETS ${LIB_DEPS})
        list(APPEND LIB_INCLUDES ${LIB_DEPS_INCLUDES})
    endforeach()

    set(${VAR_NAME}          ${LIB_TARGETS}  PARENT_SCOPE)
    set(${VAR_NAME}_INCLUDES ${LIB_INCLUDES} PARENT_SCOPE)
endfunction()

function(setup_arduino_target TARGET_NAME BOARD_ID ALL_SRCS ALL_LIBS COMPILE_FLAGS LINK_FLAGS MANUAL)

    add_executable(${TARGET_NAME} ${ALL_SRCS})
    set_target_properties(${TARGET_NAME} PROPERTIES SUFFIX ".elf")

    get_arduino_flags(ARDUINO_COMPILE_FLAGS ARDUINO_LINK_FLAGS  ${BOARD_ID} ${MANUAL})

    set_target_properties(${TARGET_NAME} PROPERTIES
            COMPILE_FLAGS "${ARDUINO_COMPILE_FLAGS} ${COMPILE_FLAGS}"
            LINK_FLAGS "${ARDUINO_LINK_FLAGS} ${LINK_FLAGS}")
    target_link_libraries(${TARGET_NAME} ${ALL_LIBS} "-lc -lm")

    if(NOT EXECUTABLE_OUTPUT_PATH)
        set(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    set(TARGET_PATH ${EXECUTABLE_OUTPUT_PATH}/${TARGET_NAME})

    message(STATUS "Using ${CMAKE_OBJCOPY} for converting firmware image to hex")
    add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY}
            ARGS     ${ARDUINO_OBJCOPY_EEP_FLAGS}
            ${TARGET_PATH}.elf
            ${TARGET_PATH}.eep
            COMMENT "Generating EEP image"
            VERBATIM)

    # Convert firmware image to ASCII HEX format
    add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_OBJCOPY}
            ARGS    ${ARDUINO_OBJCOPY_HEX_FLAGS}
            ${TARGET_PATH}.elf
            ${TARGET_PATH}.hex
            COMMENT "Generating HEX image"
            VERBATIM)

    # Display target size
    add_custom_command(TARGET ${TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND}
            ARGS    -DFIRMWARE_IMAGE=${TARGET_PATH}.elf
            -DMCU=${${BOARD_ID}${ARDUINO_CPUMENU}.build.mcu}
            -DEEPROM_IMAGE=${TARGET_PATH}.eep
            -P ${ARDUINO_SIZE_SCRIPT}
            COMMENT "Calculating image size"
            VERBATIM)

    # Create ${TARGET_NAME}-size target
    add_custom_target(${TARGET_NAME}-size
            COMMAND ${CMAKE_COMMAND}
            -DFIRMWARE_IMAGE=${TARGET_PATH}.elf
            -DMCU=${${BOARD_ID}${ARDUINO_CPUMENU}.build.mcu}
            -DEEPROM_IMAGE=${TARGET_PATH}.eep
            -P ${ARDUINO_SIZE_SCRIPT}
            DEPENDS ${TARGET_NAME}
            COMMENT "Calculating ${TARGET_NAME} image size")

endfunction()

function(setup_arduino_upload BOARD_ID TARGET_NAME PORT PROGRAMMER_ID AVRDUDE_FLAGS)
    setup_arduino_bootloader_upload(${TARGET_NAME} ${BOARD_ID} ${PORT} "${AVRDUDE_FLAGS}")

    # Add programmer support if defined
    if(PROGRAMMER_ID AND ${PROGRAMMER_ID}.protocol)
        setup_arduino_programmer_burn(${TARGET_NAME} ${BOARD_ID} ${PROGRAMMER_ID} ${PORT} "${AVRDUDE_FLAGS}")
        setup_arduino_bootloader_burn(${TARGET_NAME} ${BOARD_ID} ${PROGRAMMER_ID} ${PORT} "${AVRDUDE_FLAGS}")
    endif()
endfunction()

function(setup_arduino_bootloader_upload TARGET_NAME BOARD_ID PORT AVRDUDE_FLAGS)
    set(UPLOAD_TARGET ${TARGET_NAME}-upload)
    set(AVRDUDE_ARGS)

    setup_arduino_bootloader_args(${BOARD_ID} ${TARGET_NAME} ${PORT} "${AVRDUDE_FLAGS}" AVRDUDE_ARGS)

    if(NOT AVRDUDE_ARGS)
        message("Could not generate default avrdude bootloader args, aborting!")
        return()
    endif()

    if(NOT EXECUTABLE_OUTPUT_PATH)
        set(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    set(TARGET_PATH ${EXECUTABLE_OUTPUT_PATH}/${TARGET_NAME})

    list(APPEND AVRDUDE_ARGS "-Uflash:w:${TARGET_PATH}.hex:i")
    list(APPEND AVRDUDE_ARGS "-Ueeprom:w:${TARGET_PATH}.eep:i")
    add_custom_target(${UPLOAD_TARGET}
            ${ARDUINO_AVRDUDE_PROGRAM}
            ${AVRDUDE_ARGS}
            DEPENDS ${TARGET_NAME})

    # Global upload target
    if(NOT TARGET upload)
        add_custom_target(upload)
    endif()

    add_dependencies(upload ${UPLOAD_TARGET})
endfunction()

function(setup_arduino_programmer_burn TARGET_NAME BOARD_ID PROGRAMMER PORT AVRDUDE_FLAGS)
    set(PROGRAMMER_TARGET ${TARGET_NAME}-burn)

    set(AVRDUDE_ARGS)

    setup_arduino_programmer_args(${BOARD_ID} ${PROGRAMMER} ${TARGET_NAME} ${PORT} "${AVRDUDE_FLAGS}" AVRDUDE_ARGS)

    if(NOT AVRDUDE_ARGS)
        message("Could not generate default avrdude programmer args, aborting!")
        return()
    endif()

    if(NOT EXECUTABLE_OUTPUT_PATH)
        set(EXECUTABLE_OUTPUT_PATH ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    set(TARGET_PATH ${EXECUTABLE_OUTPUT_PATH}/${TARGET_NAME})

    list(APPEND AVRDUDE_ARGS "-Uflash:w:${TARGET_PATH}.hex")

    add_custom_target(${PROGRAMMER_TARGET}
            ${ARDUINO_AVRDUDE_PROGRAM}
            ${AVRDUDE_ARGS}
            DEPENDS ${TARGET_NAME})
endfunction()

function(setup_arduino_bootloader_burn TARGET_NAME BOARD_ID PROGRAMMER PORT AVRDUDE_FLAGS)
    set(BOOTLOADER_TARGET ${TARGET_NAME}-burn-bootloader)

    set(AVRDUDE_ARGS)

    setup_arduino_programmer_args(${BOARD_ID} ${PROGRAMMER} ${TARGET_NAME} ${PORT} "${AVRDUDE_FLAGS}" AVRDUDE_ARGS)

    if(NOT AVRDUDE_ARGS)
        message("Could not generate default avrdude programmer args, aborting!")
        return()
    endif()

    foreach( ITEM unlock_bits high_fuses low_fuses path file)
        if(NOT ${BOARD_ID}.bootloader.${ITEM})
            message("Missing ${BOARD_ID}.bootloader.${ITEM}, not creating bootloader burn target ${BOOTLOADER_TARGET}.")
            return()
        endif()
    endforeach()

    if(NOT EXISTS "${ARDUINO_BOOTLOADERS_PATH}/${${BOARD_ID}.bootloader.path}/${${BOARD_ID}${ARDUINO_CPUMENU}.bootloader.file}")
        message("${ARDUINO_BOOTLOADERS_PATH}/${${BOARD_ID}.bootloader.path}/${${BOARD_ID}${ARDUINO_CPUMENU}.bootloader.file}")
        message("Missing bootloader image, not creating bootloader burn target ${BOOTLOADER_TARGET}.")
        return()
    endif()

    # Erase the chip
    list(APPEND AVRDUDE_ARGS "-e")

    # Set unlock bits and fuses (because chip is going to be erased)
    list(APPEND AVRDUDE_ARGS "-Ulock:w:${${BOARD_ID}.bootloader.unlock_bits}:m")
    if(${BOARD_ID}.bootloader.extended_fuses)
        list(APPEND AVRDUDE_ARGS "-Uefuse:w:${${BOARD_ID}${ARDUINO_CPUMENU}.bootloader.extended_fuses}:m")
    endif()
    list(APPEND AVRDUDE_ARGS
            "-Uhfuse:w:${${BOARD_ID}${ARDUINO_CPUMENU}.bootloader.high_fuses}:m"
            "-Ulfuse:w:${${BOARD_ID}.bootloader.low_fuses}:m")

    # Set bootloader image
    list(APPEND AVRDUDE_ARGS "-Uflash:w:${${BOARD_ID}${ARDUINO_CPUMENU}.bootloader.file}:i")

    # Set lockbits
    list(APPEND AVRDUDE_ARGS "-Ulock:w:${${BOARD_ID}.bootloader.lock_bits}:m")

    # Create burn bootloader target
    add_custom_target(${BOOTLOADER_TARGET}
            ${ARDUINO_AVRDUDE_PROGRAM}
            ${AVRDUDE_ARGS}
            WORKING_DIRECTORY ${ARDUINO_BOOTLOADERS_PATH}/${${BOARD_ID}.bootloader.path}
            DEPENDS ${TARGET_NAME})
endfunction()

function(setup_arduino_programmer_args BOARD_ID PROGRAMMER TARGET_NAME PORT AVRDUDE_FLAGS OUTPUT_VAR)
    set(AVRDUDE_ARGS ${${OUTPUT_VAR}})

    if(NOT AVRDUDE_FLAGS)
        set(AVRDUDE_FLAGS ${ARDUINO_AVRDUDE_FLAGS})
    endif()

    list(APPEND AVRDUDE_ARGS "-C${ARDUINO_AVRDUDE_CONFIG_PATH}")

    #TODO: Check mandatory settings before continuing
    if(NOT ${PROGRAMMER}.protocol)
        message(FATAL_ERROR "Missing ${PROGRAMMER}.protocol, aborting!")
    endif()

    list(APPEND AVRDUDE_ARGS "-c${${PROGRAMMER}.protocol}") # Set programmer

    if(${PROGRAMMER}.communication STREQUAL "usb")
        list(APPEND AVRDUDE_ARGS "-Pusb") # Set USB as port
    elseif(${PROGRAMMER}.communication STREQUAL "serial")
        list(APPEND AVRDUDE_ARGS "-P${PORT}") # Set port
        if(${PROGRAMMER}.speed)
            list(APPEND AVRDUDE_ARGS "-b${${PROGRAMMER}.speed}") # Set baud rate
        endif()
    endif()

    if(${PROGRAMMER}.force)
        list(APPEND AVRDUDE_ARGS "-F") # Set force
    endif()

    if(${PROGRAMMER}.delay)
        list(APPEND AVRDUDE_ARGS "-i${${PROGRAMMER}.delay}") # Set delay
    endif()

    list(APPEND AVRDUDE_ARGS "-p${${BOARD_ID}${ARDUINO_CPUMENU}.build.mcu}")  # MCU Type

    list(APPEND AVRDUDE_ARGS ${AVRDUDE_FLAGS})

    set(${OUTPUT_VAR} ${AVRDUDE_ARGS} PARENT_SCOPE)
endfunction()

function(setup_arduino_bootloader_args BOARD_ID TARGET_NAME PORT AVRDUDE_FLAGS OUTPUT_VAR)
    set(AVRDUDE_ARGS ${${OUTPUT_VAR}})

    if(NOT AVRDUDE_FLAGS)
        set(AVRDUDE_FLAGS ${ARDUINO_AVRDUDE_FLAGS})
    endif()

    list(APPEND AVRDUDE_ARGS
            "-C${ARDUINO_AVRDUDE_CONFIG_PATH}"  # avrdude config
            "-p${${BOARD_ID}${ARDUINO_CPUMENU}.build.mcu}"        # MCU Type
            )

    # Programmer
    if(NOT ${BOARD_ID}${ARDUINO_CPUMENU}.upload.protocol OR ${BOARD_ID}${ARDUINO_CPUMENU}.upload.protocol STREQUAL "stk500")
        if(NOT ${BOARD_ID}.upload.protocol OR ${BOARD_ID}.upload.protocol STREQUAL "stk500")
            list(APPEND AVRDUDE_ARGS "-cstk500v1")
        else()
            list(APPEND AVRDUDE_ARGS "-c${${BOARD_ID}.upload.protocol}")
        endif()
    else()
        list(APPEND AVRDUDE_ARGS "-c${${BOARD_ID}${ARDUINO_CPUMENU}.upload.protocol}")
    endif()

    set(UPLOAD_SPEED "19200")
    if(${BOARD_ID}${ARDUINO_CPUMENU}.upload.speed)
        set(UPLOAD_SPEED ${${BOARD_ID}${ARDUINO_CPUMENU}.upload.speed})
    endif()

    list(APPEND AVRDUDE_ARGS
            "-b${UPLOAD_SPEED}"     # Baud rate
            "-P${PORT}"                         # Serial port
            "-D"                                # Dont erase
            )

    list(APPEND AVRDUDE_ARGS ${AVRDUDE_FLAGS})

    set(${OUTPUT_VAR} ${AVRDUDE_ARGS} PARENT_SCOPE)
endfunction()

function(find_sources VAR_NAME LIB_PATH RECURSE)
    set(FILE_SEARCH_LIST
            ${LIB_PATH}/*.cpp
            ${LIB_PATH}/*.c
            ${LIB_PATH}/*.cc
            ${LIB_PATH}/*.cxx
            ${LIB_PATH}/*.h
            ${LIB_PATH}/*.hh
            ${LIB_PATH}/*.hxx)

    if(RECURSE)
        file(GLOB_RECURSE LIB_FILES ${FILE_SEARCH_LIST})
    else()
        file(GLOB LIB_FILES ${FILE_SEARCH_LIST})
    endif()

    if(LIB_FILES)
        set(${VAR_NAME} ${LIB_FILES} PARENT_SCOPE)
    endif()
endfunction()

function(setup_serial_target TARGET_NAME CMD SERIAL_PORT)
    string(CONFIGURE "${CMD}" FULL_CMD @ONLY)
    add_custom_target(${TARGET_NAME}-serial
            COMMAND ${FULL_CMD})
endfunction()

function(detect_arduino_version VAR_NAME)
    if(ARDUINO_VERSION_PATH)
        file(READ ${ARDUINO_VERSION_PATH} RAW_VERSION)
        if("${RAW_VERSION}" MATCHES " *[0]+([0-9]+)")
            set(PARSED_VERSION 0.${CMAKE_MATCH_1}.0)
        elseif("${RAW_VERSION}" MATCHES "[ ]*([0-9]+[.][0-9]+[.][0-9]+)")
            set(PARSED_VERSION ${CMAKE_MATCH_1})
        elseif("${RAW_VERSION}" MATCHES "[ ]*([0-9]+[.][0-9]+)")
            set(PARSED_VERSION ${CMAKE_MATCH_1}.0)
        endif()

        if(NOT PARSED_VERSION STREQUAL "")
            string(REPLACE "." ";" SPLIT_VERSION ${PARSED_VERSION})
            list(GET SPLIT_VERSION 0 SPLIT_VERSION_MAJOR)
            list(GET SPLIT_VERSION 1 SPLIT_VERSION_MINOR)
            list(GET SPLIT_VERSION 2 SPLIT_VERSION_PATCH)

            set(${VAR_NAME}       "${PARSED_VERSION}"      PARENT_SCOPE)
            set(${VAR_NAME}_MAJOR "${SPLIT_VERSION_MAJOR}" PARENT_SCOPE)
            set(${VAR_NAME}_MINOR "${SPLIT_VERSION_MINOR}" PARENT_SCOPE)
            set(${VAR_NAME}_PATCH "${SPLIT_VERSION_PATCH}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

function(LOAD_ARDUINO_STYLE_SETTINGS SETTINGS_LIST SETTINGS_PATH)

    if(NOT ${SETTINGS_LIST} AND EXISTS ${SETTINGS_PATH})
        file(STRINGS ${SETTINGS_PATH} FILE_ENTRIES)  # Settings file split into lines

        foreach(FILE_ENTRY ${FILE_ENTRIES})
            if("${FILE_ENTRY}" MATCHES "^[^#]+=.*")
                string(REGEX MATCH "^[^=]+" SETTING_NAME  ${FILE_ENTRY})
                string(REGEX MATCH "[^=]+$" SETTING_VALUE ${FILE_ENTRY})
                string(REPLACE "." ";" ENTRY_NAME_TOKENS ${SETTING_NAME})
                string(STRIP "${SETTING_VALUE}" SETTING_VALUE)

                list(LENGTH ENTRY_NAME_TOKENS ENTRY_NAME_TOKENS_LEN)

                # Add entry to settings list if it does not exist
                list(GET ENTRY_NAME_TOKENS 0 ENTRY_NAME)
                list(FIND ${SETTINGS_LIST} ${ENTRY_NAME} ENTRY_NAME_INDEX)
                if(ENTRY_NAME_INDEX LESS 0)
                    # Add entry to main list
                    list(APPEND ${SETTINGS_LIST} ${ENTRY_NAME})
                endif()

                # Add entry setting to entry settings list if it does not exist
                set(ENTRY_SETTING_LIST ${ENTRY_NAME}.SETTINGS)
                list(GET ENTRY_NAME_TOKENS 1 ENTRY_SETTING)
                set(PARAMETERS 2)
                if(ENTRY_SETTING STREQUAL "menu")
                    list(GET ENTRY_NAME_TOKENS 3 CPUNAME)
                    if(ENTRY_NAME_TOKENS_LEN GREATER 4)
                        list(GET ENTRY_NAME_TOKENS 4 PROPERTYNAME)
                        set(ENTRY_SETTING "menu.cpu.${CPUNAME}.${PROPERTYNAME}")
                        set(PARAMETERS 5)
                    else()
                        set(ENTRY_SETTING "menu.cpu.${CPUNAME}")
                        set(PARAMETERS 4)
                    endif()
                    list(APPEND ${ENTRY_SETTING_LIST} "${ENTRY_SETTING}")
                else()
                    list(FIND ${ENTRY_SETTING_LIST} ${ENTRY_SETTING} ENTRY_SETTING_INDEX)
                    if(ENTRY_SETTING_INDEX LESS 0)
                        # Add setting to entry
                        list(APPEND ${ENTRY_SETTING_LIST} ${ENTRY_SETTING})
                        set(${ENTRY_SETTING_LIST} ${${ENTRY_SETTING_LIST}}
                                CACHE INTERNAL "Arduino ${ENTRY_NAME} Board settings list")
                    endif()
                endif()

                set(FULL_SETTING_NAME ${ENTRY_NAME}.${ENTRY_SETTING})

                # Add entry sub-setting to entry sub-settings list if it does not exists
                if(ENTRY_NAME_TOKENS_LEN GREATER ${PARAMETERS})
                    set(ENTRY_SUBSETTING_LIST ${ENTRY_NAME}.${ENTRY_SETTING}.SUBSETTINGS)
                    list(GET ENTRY_NAME_TOKENS ${PARAMETERS} ENTRY_SUBSETTING)
                    list(FIND ${ENTRY_SUBSETTING_LIST} ${ENTRY_SUBSETTING} ENTRY_SUBSETTING_INDEX)
                    if(ENTRY_SUBSETTING_INDEX LESS 0)
                        list(APPEND ${ENTRY_SUBSETTING_LIST} ${ENTRY_SUBSETTING})
                        set(${ENTRY_SUBSETTING_LIST}  ${${ENTRY_SUBSETTING_LIST}}
                                CACHE INTERNAL "Arduino ${ENTRY_NAME} Board sub-settings list")
                    endif()
                    set(FULL_SETTING_NAME ${FULL_SETTING_NAME}.${ENTRY_SUBSETTING})
                endif()

                # Save setting value
                set(${FULL_SETTING_NAME} ${SETTING_VALUE}
                        CACHE INTERNAL "Arduino ${ENTRY_NAME} Board setting")


            endif()
        endforeach()
        set(${SETTINGS_LIST} ${${SETTINGS_LIST}}
                CACHE STRING "List of detected Arduino Board configurations")
        mark_as_advanced(${SETTINGS_LIST})
    endif()
endfunction()

function(PRINT_SETTINGS ENTRY_NAME)
    if(${ENTRY_NAME}.SETTINGS)

        foreach(ENTRY_SETTING ${${ENTRY_NAME}.SETTINGS})
            if(${ENTRY_NAME}.${ENTRY_SETTING})
                message(STATUS "   ${ENTRY_NAME}.${ENTRY_SETTING}=${${ENTRY_NAME}.${ENTRY_SETTING}}")
            endif()
            if(${ENTRY_NAME}.${ENTRY_SETTING}.SUBSETTINGS)
                foreach(ENTRY_SUBSETTING ${${ENTRY_NAME}.${ENTRY_SETTING}.SUBSETTINGS})
                    if(${ENTRY_NAME}.${ENTRY_SETTING}.${ENTRY_SUBSETTING})
                        message(STATUS "   ${ENTRY_NAME}.${ENTRY_SETTING}.${ENTRY_SUBSETTING}=${${ENTRY_NAME}.${ENTRY_SETTING}.${ENTRY_SUBSETTING}}")
                    endif()
                endforeach()
            endif()
            message(STATUS "")
        endforeach()
    endif()
endfunction()

function(PRINT_LIST SETTINGS_LIST)
    if(${SETTINGS_LIST})
        set(MAX_LENGTH 0)
        foreach(ENTRY_NAME ${${SETTINGS_LIST}})
            string(LENGTH "${ENTRY_NAME}" CURRENT_LENGTH)
            if(CURRENT_LENGTH GREATER MAX_LENGTH)
                set(MAX_LENGTH ${CURRENT_LENGTH})
            endif()
        endforeach()
        foreach(ENTRY_NAME ${${SETTINGS_LIST}})
            string(LENGTH "${ENTRY_NAME}" CURRENT_LENGTH)
            math(EXPR PADDING_LENGTH "${MAX_LENGTH}-${CURRENT_LENGTH}")
            set(PADDING "")
            foreach(X RANGE ${PADDING_LENGTH})
                set(PADDING "${PADDING} ")
            endforeach()
            message(STATUS "   ${PADDING}${ENTRY_NAME}: ${${ENTRY_NAME}.name}")
        endforeach()
    endif()
endfunction()

function(SETUP_ARDUINO_EXAMPLE TARGET_NAME LIBRARY_NAME EXAMPLE_NAME OUTPUT_VAR)
    set(EXAMPLE_SKETCH_PATH )

    get_property(LIBRARY_SEARCH_PATH
            DIRECTORY     # Property Scope
            PROPERTY LINK_DIRECTORIES)
    foreach(LIB_SEARCH_PATH ${LIBRARY_SEARCH_PATH} ${ARDUINO_LIBRARIES_PATH} ${${ARDUINO_PLATFORM}_LIBRARIES_PATH} . ${CMAKE_CURRENT_SOURCE_DIR}/libraries)
        message(STATUS "Search ${LIBRARY_NAME} example directory in ${LIB_SEARCH_PATH}")
        if(EXISTS "${LIB_SEARCH_PATH}/${LIBRARY_NAME}/examples/${EXAMPLE_NAME}")
            set(EXAMPLE_SKETCH_PATH "${LIB_SEARCH_PATH}/${LIBRARY_NAME}/examples/${EXAMPLE_NAME}")
            break()
        endif()
    endforeach()

    if(EXAMPLE_SKETCH_PATH)
        setup_arduino_sketch(${TARGET_NAME} ${EXAMPLE_SKETCH_PATH} SKETCH_CPP)
        set("${OUTPUT_VAR}" ${${OUTPUT_VAR}} ${SKETCH_CPP} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Could not find example ${EXAMPLE_NAME} from library ${LIBRARY_NAME}")
    endif()
endfunction()

function(SETUP_ARDUINO_SKETCH TARGET_NAME SKETCH_PATH OUTPUT_VAR)
    get_filename_component(SKETCH_NAME "${SKETCH_PATH}" NAME)
    get_filename_component(SKETCH_PATH "${SKETCH_PATH}" ABSOLUTE)

    if(EXISTS "${SKETCH_PATH}")
        set(SKETCH_CPP  ${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}_${SKETCH_NAME}.cpp)

        if (IS_DIRECTORY "${SKETCH_PATH}")
            # Sketch directory specified, try to find main sketch...
            set(MAIN_SKETCH ${SKETCH_PATH}/${SKETCH_NAME})

            if(EXISTS "${MAIN_SKETCH}.pde")
                set(MAIN_SKETCH "${MAIN_SKETCH}.pde")
            elseif(EXISTS "${MAIN_SKETCH}.ino")
                set(MAIN_SKETCH "${MAIN_SKETCH}.ino")
            else()
                message(FATAL_ERROR "Could not find main sketch (${SKETCH_NAME}.pde or ${SKETCH_NAME}.ino) at ${SKETCH_PATH}! Please specify the main sketch file path instead of directory.")
            endif()
        else()
            # Sektch file specified, assuming parent directory as sketch directory
            set(MAIN_SKETCH ${SKETCH_PATH})
            get_filename_component(SKETCH_PATH "${SKETCH_PATH}" PATH)
        endif()
        arduino_debug_msg("sketch: ${MAIN_SKETCH}")

        # Find all sketch files
        file(GLOB SKETCH_SOURCES ${SKETCH_PATH}/*.pde ${SKETCH_PATH}/*.ino)
        set(ALL_SRCS ${SKETCH_SOURCES})

        list(REMOVE_ITEM SKETCH_SOURCES ${MAIN_SKETCH})
        list(SORT SKETCH_SOURCES)



        generate_cpp_from_sketch("${MAIN_SKETCH}" "${SKETCH_SOURCES}" "${SKETCH_CPP}")

        # Regenerate build system if sketch changes
        add_custom_command(OUTPUT ${SKETCH_CPP}
                COMMAND ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
                WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
                DEPENDS ${MAIN_SKETCH} ${SKETCH_SOURCES}
                COMMENT "Regnerating ${SKETCH_NAME} Sketch")
        set_source_files_properties(${SKETCH_CPP} PROPERTIES GENERATED TRUE)
        # Mark file that it exists for find_file
        set_source_files_properties(${SKETCH_CPP} PROPERTIES GENERATED_SKETCH TRUE)

        set("${OUTPUT_VAR}" ${${OUTPUT_VAR}} ${SKETCH_CPP} PARENT_SCOPE)
    else()
        message(FATAL_ERROR "Sketch does not exist: ${SKETCH_PATH}")
    endif()
endfunction()

function(GENERATE_CPP_FROM_SKETCH MAIN_SKETCH_PATH SKETCH_SOURCES SKETCH_CPP)
    file(WRITE ${SKETCH_CPP} "// automatically generated by arduino-cmake\n")
    file(READ  ${MAIN_SKETCH_PATH} MAIN_SKETCH)

    # remove comments
    remove_comments(MAIN_SKETCH MAIN_SKETCH_NO_COMMENTS)

    # find first statement
    string(REGEX MATCH "[\n][_a-zA-Z0-9]+[^\n]*" FIRST_STATEMENT "${MAIN_SKETCH_NO_COMMENTS}")
    string(FIND "${MAIN_SKETCH}" "${FIRST_STATEMENT}" HEAD_LENGTH)
    if ("${HEAD_LENGTH}" STREQUAL "-1")
        set(HEAD_LENGTH 0)
    endif()
    #message(STATUS "FIRST STATEMENT: ${FIRST_STATEMENT}")
    #message(STATUS "FIRST STATEMENT POSITION: ${HEAD_LENGTH}")
    string(LENGTH "${MAIN_SKETCH}" MAIN_SKETCH_LENGTH)

    string(SUBSTRING "${MAIN_SKETCH}" 0 ${HEAD_LENGTH} SKETCH_HEAD)
    #arduino_debug_msg("SKETCH_HEAD:\n${SKETCH_HEAD}")

    # find the body of the main pde
    math(EXPR BODY_LENGTH "${MAIN_SKETCH_LENGTH}-${HEAD_LENGTH}")
    string(SUBSTRING "${MAIN_SKETCH}" "${HEAD_LENGTH}+1" "${BODY_LENGTH}-1" SKETCH_BODY)
    #arduino_debug_msg("BODY:\n${SKETCH_BODY}")

    # write the file head
    file(APPEND ${SKETCH_CPP} "#line 1 \"${MAIN_SKETCH_PATH}\"\n${SKETCH_HEAD}")

    # Count head line offset (for GCC error reporting)
    file(STRINGS ${SKETCH_CPP} SKETCH_HEAD_LINES)
    list(LENGTH SKETCH_HEAD_LINES SKETCH_HEAD_LINES_COUNT)
    math(EXPR SKETCH_HEAD_OFFSET "${SKETCH_HEAD_LINES_COUNT}+2")

    # add arduino include header
    #file(APPEND ${SKETCH_CPP} "\n#line 1 \"autogenerated\"\n")
    file(APPEND ${SKETCH_CPP} "\n#line ${SKETCH_HEAD_OFFSET} \"${SKETCH_CPP}\"\n")
    if(ARDUINO_SDK_VERSION VERSION_LESS 1.0)
        file(APPEND ${SKETCH_CPP} "#include \"WProgram.h\"\n")
    else()
        file(APPEND ${SKETCH_CPP} "#include \"Arduino.h\"\n")
    endif()

    # add function prototypes
    foreach(SKETCH_SOURCE_PATH ${SKETCH_SOURCES} ${MAIN_SKETCH_PATH})
        arduino_debug_msg("Sketch: ${SKETCH_SOURCE_PATH}")
        file(READ ${SKETCH_SOURCE_PATH} SKETCH_SOURCE)
        remove_comments(SKETCH_SOURCE SKETCH_SOURCE)

        set(ALPHA "a-zA-Z")
        set(NUM "0-9")
        set(ALPHANUM "${ALPHA}${NUM}")
        set(WORD "_${ALPHANUM}")
        set(LINE_START "(^|[\n])")
        set(QUALIFIERS "[ \t]*([${ALPHA}]+[ ])*")
        set(TYPE "[${WORD}]+([ ]*[\n][\t]*|[ ])+")
        set(FNAME "[${WORD}]+[ ]?[\n]?[\t]*[ ]*")
        set(FARGS "[(]([\t]*[ ]*[*&]?[ ]?[${WORD}](\\[([${NUM}]+)?\\])*[,]?[ ]*[\n]?)*([,]?[ ]*[\n]?)?[)]")
        set(BODY_START "([ ]*[\n][\t]*|[ ]|[\n])*{")
        set(PROTOTYPE_PATTERN "${LINE_START}${QUALIFIERS}${TYPE}${FNAME}${FARGS}${BODY_START}")

        string(REGEX MATCHALL "${PROTOTYPE_PATTERN}" SKETCH_PROTOTYPES "${SKETCH_SOURCE}")

        # Write function prototypes
        file(APPEND ${SKETCH_CPP} "\n//=== START Forward: ${SKETCH_SOURCE_PATH}\n")
        foreach(SKETCH_PROTOTYPE ${SKETCH_PROTOTYPES})
            string(REPLACE "\n" " " SKETCH_PROTOTYPE "${SKETCH_PROTOTYPE}")
            string(REPLACE "{" "" SKETCH_PROTOTYPE "${SKETCH_PROTOTYPE}")
            arduino_debug_msg("\tprototype: ${SKETCH_PROTOTYPE};")
            # " else if(var == other) {" shoudn't be listed as prototype
            if(NOT SKETCH_PROTOTYPE MATCHES "(if[ ]?[\n]?[\t]*[ ]*[)])")
                file(APPEND ${SKETCH_CPP} "${SKETCH_PROTOTYPE};\n")
            else()
                arduino_debug_msg("\trejected prototype: ${SKETCH_PROTOTYPE};")
            endif()
            file(APPEND ${SKETCH_CPP} "${SKETCH_PROTOTYPE};\n")
        endforeach()
        file(APPEND ${SKETCH_CPP} "//=== END Forward: ${SKETCH_SOURCE_PATH}\n")
    endforeach()

    # Write Sketch CPP source
    get_num_lines("${SKETCH_HEAD}" HEAD_NUM_LINES)
    file(APPEND ${SKETCH_CPP} "#line ${HEAD_NUM_LINES} \"${MAIN_SKETCH_PATH}\"\n")
    file(APPEND ${SKETCH_CPP} "\n${SKETCH_BODY}")
    foreach (SKETCH_SOURCE_PATH ${SKETCH_SOURCES})
        file(READ ${SKETCH_SOURCE_PATH} SKETCH_SOURCE)
        file(APPEND ${SKETCH_CPP} "\n//=== START : ${SKETCH_SOURCE_PATH}\n")
        file(APPEND ${SKETCH_CPP} "#line 1 \"${SKETCH_SOURCE_PATH}\"\n")
        file(APPEND ${SKETCH_CPP} "${SKETCH_SOURCE}")
        file(APPEND ${SKETCH_CPP} "\n//=== END : ${SKETCH_SOURCE_PATH}\n")
    endforeach()
endfunction()

function(SETUP_ARDUINO_SIZE_SCRIPT OUTPUT_VAR)
    set(ARDUINO_SIZE_SCRIPT_PATH ${CMAKE_BINARY_DIR}/CMakeFiles/FirmwareSize.cmake)

    file(WRITE ${ARDUINO_SIZE_SCRIPT_PATH} "
        set(AVRSIZE_PROGRAM \"${AVRSIZE_PROGRAM}\")
        set(AVRSIZE_FLAGS -C --mcu=\${MCU})

        execute_process(COMMAND \${AVRSIZE_PROGRAM} \${AVRSIZE_FLAGS} \${FIRMWARE_IMAGE} \${EEPROM_IMAGE}
                        OUTPUT_VARIABLE SIZE_OUTPUT)


        string(STRIP \"\${SIZE_OUTPUT}\" RAW_SIZE_OUTPUT)

        # Convert lines into a list
        string(REPLACE \"\\n\" \";\" SIZE_OUTPUT_LIST \"\${SIZE_OUTPUT}\")

        set(SIZE_OUTPUT_LINES)
        foreach(LINE \${SIZE_OUTPUT_LIST})
            if(NOT \"\${LINE}\" STREQUAL \"\")
                list(APPEND SIZE_OUTPUT_LINES \"\${LINE}\")
            endif()
        endforeach()

        function(EXTRACT LIST_NAME INDEX VARIABLE)
            list(GET \"\${LIST_NAME}\" \${INDEX} RAW_VALUE)
            string(STRIP \"\${RAW_VALUE}\" VALUE)

            set(\${VARIABLE} \"\${VALUE}\" PARENT_SCOPE)
        endfunction()
        function(PARSE INPUT VARIABLE_PREFIX)
            if(\${INPUT} MATCHES \"([^:]+):[ \\t]*([0-9]+)[ \\t]*([^ \\t]+)[ \\t]*[(]([0-9.]+)%.*\")
                set(ENTRY_NAME      \${CMAKE_MATCH_1})
                set(ENTRY_SIZE      \${CMAKE_MATCH_2})
                set(ENTRY_SIZE_TYPE \${CMAKE_MATCH_3})
                set(ENTRY_PERCENT   \${CMAKE_MATCH_4})
            endif()

            set(\${VARIABLE_PREFIX}_NAME      \${ENTRY_NAME}      PARENT_SCOPE)
            set(\${VARIABLE_PREFIX}_SIZE      \${ENTRY_SIZE}      PARENT_SCOPE)
            set(\${VARIABLE_PREFIX}_SIZE_TYPE \${ENTRY_SIZE_TYPE} PARENT_SCOPE)
            set(\${VARIABLE_PREFIX}_PERCENT   \${ENTRY_PERCENT}   PARENT_SCOPE)
        endfunction()

        list(LENGTH SIZE_OUTPUT_LINES SIZE_OUTPUT_LENGTH)
        #message(\"\${SIZE_OUTPUT_LINES}\")
        #message(\"\${SIZE_OUTPUT_LENGTH}\")
        if (\${SIZE_OUTPUT_LENGTH} STREQUAL 14)
            EXTRACT(SIZE_OUTPUT_LINES 3 FIRMWARE_PROGRAM_SIZE_ROW)
            EXTRACT(SIZE_OUTPUT_LINES 5 FIRMWARE_DATA_SIZE_ROW)
            PARSE(FIRMWARE_PROGRAM_SIZE_ROW FIRMWARE_PROGRAM)
            PARSE(FIRMWARE_DATA_SIZE_ROW  FIRMWARE_DATA)

            set(FIRMWARE_STATUS \"Firmware Size: \")
            set(FIRMWARE_STATUS \"\${FIRMWARE_STATUS} [\${FIRMWARE_PROGRAM_NAME}: \${FIRMWARE_PROGRAM_SIZE} \${FIRMWARE_PROGRAM_SIZE_TYPE} (\${FIRMWARE_PROGRAM_PERCENT}%)] \")
            set(FIRMWARE_STATUS \"\${FIRMWARE_STATUS} [\${FIRMWARE_DATA_NAME}: \${FIRMWARE_DATA_SIZE} \${FIRMWARE_DATA_SIZE_TYPE} (\${FIRMWARE_DATA_PERCENT}%)]\")
            set(FIRMWARE_STATUS \"\${FIRMWARE_STATUS} on \${MCU}\")

            EXTRACT(SIZE_OUTPUT_LINES 10 EEPROM_PROGRAM_SIZE_ROW)
            EXTRACT(SIZE_OUTPUT_LINES 12 EEPROM_DATA_SIZE_ROW)
            PARSE(EEPROM_PROGRAM_SIZE_ROW EEPROM_PROGRAM)
            PARSE(EEPROM_DATA_SIZE_ROW  EEPROM_DATA)

            set(EEPROM_STATUS \"EEPROM   Size: \")
            set(EEPROM_STATUS \"\${EEPROM_STATUS} [\${EEPROM_PROGRAM_NAME}: \${EEPROM_PROGRAM_SIZE} \${EEPROM_PROGRAM_SIZE_TYPE} (\${EEPROM_PROGRAM_PERCENT}%)] \")
            set(EEPROM_STATUS \"\${EEPROM_STATUS} [\${EEPROM_DATA_NAME}: \${EEPROM_DATA_SIZE} \${EEPROM_DATA_SIZE_TYPE} (\${EEPROM_DATA_PERCENT}%)]\")
            set(EEPROM_STATUS \"\${EEPROM_STATUS} on \${MCU}\")

            message(\"\${FIRMWARE_STATUS}\")
            message(\"\${EEPROM_STATUS}\\n\")

            if(\$ENV{VERBOSE})
                message(\"\${RAW_SIZE_OUTPUT}\\n\")
            elseif(\$ENV{VERBOSE_SIZE})
                message(\"\${RAW_SIZE_OUTPUT}\\n\")
            endif()
        else()
            message(\"\${RAW_SIZE_OUTPUT}\")
        endif()
    ")

    set(${OUTPUT_VAR} ${ARDUINO_SIZE_SCRIPT_PATH} PARENT_SCOPE)
endfunction()

function(ARDUINO_DEBUG_ON)
    set(ARDUINO_DEBUG True PARENT_SCOPE)
endfunction()

function(ARDUINO_DEBUG_OFF)
    set(ARDUINO_DEBUG False PARENT_SCOPE)
endfunction()

function(ARDUINO_DEBUG_MSG MSG)
    if(ARDUINO_DEBUG)
        message("## ${MSG}")
    endif()
endfunction()

function(REMOVE_COMMENTS SRC_VAR OUT_VAR)
    string(REGEX REPLACE "[\\./\\\\]" "_" FILE "${NAME}")

    set(SRC ${${SRC_VAR}})

    #message(STATUS "removing comments from: ${FILE}")
    #file(WRITE "${CMAKE_BINARY_DIR}/${FILE}_pre_remove_comments.txt" ${SRC})
    #message(STATUS "\n${SRC}")

    # remove all comments
    string(REGEX REPLACE "([/][/][^\n]*)|([/][\\*]([^\\*]|([\\*]+[^/\\*]))*[\\*]+[/])" "" OUT "${SRC}")

    #file(WRITE "${CMAKE_BINARY_DIR}/${FILE}_post_remove_comments.txt" ${SRC})
    #message(STATUS "\n${SRC}")

    set(${OUT_VAR} ${OUT} PARENT_SCOPE)

endfunction()

function(GET_NUM_LINES DOCUMENT OUTPUT_VAR)
    string(REGEX MATCHALL "[\n]" MATCH_LIST "${DOCUMENT}")
    list(LENGTH MATCH_LIST NUM)
    set(${OUTPUT_VAR} ${NUM} PARENT_SCOPE)
endfunction()

function(REQUIRED_VARIABLES)
    cmake_parse_arguments(INPUT "" "MSG" "VARS" ${ARGN})
    error_for_unparsed(INPUT)
    foreach(VAR ${INPUT_VARS})
        if ("${${VAR}}" STREQUAL "")
            message(FATAL_ERROR "${VAR} not set: ${INPUT_MSG}")
        endif()
    endforeach()
endfunction()

function(ERROR_FOR_UNPARSED PREFIX)
    set(ARGS "${${PREFIX}_UNPARSED_ARGUMENTS}")
    if (NOT ( "${ARGS}" STREQUAL "") )
        message(FATAL_ERROR "unparsed argument: ${ARGS}")
    endif()
endfunction()

if (NOT DEFINED ARDUINO_C_FLAGS)
    set(ARDUINO_C_FLAGS "-g -Os -w -ffunction-sections -fdata-sections -MMD")
endif (NOT DEFINED ARDUINO_C_FLAGS)
set(CMAKE_C_FLAGS                "${ARDUINO_C_FLAGS}" CACHE STRING "")
set(CMAKE_C_FLAGS_DEBUG          "${ARDUINO_C_FLAGS}" CACHE STRING "")
set(CMAKE_C_FLAGS_MINSIZEREL     "${ARDUINO_C_FLAGS}" CACHE STRING "")
set(CMAKE_C_FLAGS_RELEASE        "${ARDUINO_C_FLAGS}" CACHE STRING "")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "${ARDUINO_C_FLAGS}" CACHE STRING "")

if (NOT DEFINED ARDUINO_CXX_FLAGS)
    set(ARDUINO_CXX_FLAGS "-g -Os -w -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -MMD")
endif (NOT DEFINED ARDUINO_CXX_FLAGS)
set(CMAKE_CXX_FLAGS                "${ARDUINO_CXX_FLAGS}" CACHE STRING "")
set(CMAKE_CXX_FLAGS_DEBUG          "${ARDUINO_CXX_FLAGS}" CACHE STRING "")
set(CMAKE_CXX_FLAGS_MINSIZEREL     "${ARDUINO_CXX_FLAGS}" CACHE STRING "")
set(CMAKE_CXX_FLAGS_RELEASE        "${ARDUINO_CXX_FLAGS}" CACHE STRING "")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${ARDUINO_CXX_FLAGS}" CACHE STRING "")

set(ARDUINO_LINKER_FLAGS "-w -Os -Wl,--gc-sections")
set(CMAKE_EXE_LINKER_FLAGS                "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_EXE_LINKER_FLAGS_DEBUG          "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL     "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_EXE_LINKER_FLAGS_RELEASE        "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")

set(CMAKE_SHARED_LINKER_FLAGS                "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_SHARED_LINKER_FLAGS_DEBUG          "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL     "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_SHARED_LINKER_FLAGS_RELEASE        "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")

set(CMAKE_MODULE_LINKER_FLAGS                "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_MODULE_LINKER_FLAGS_DEBUG          "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_MODULE_LINKER_FLAGS_MINSIZEREL     "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_MODULE_LINKER_FLAGS_RELEASE        "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")
set(CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO "${ARDUINO_LINKER_FLAGS}" CACHE STRING "")


set(ARDUINO_OBJCOPY_EEP_FLAGS -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load
        --no-change-warnings --change-section-lma .eeprom=0   CACHE STRING "")
set(ARDUINO_OBJCOPY_HEX_FLAGS -O ihex -R .eeprom          CACHE STRING "")
set(ARDUINO_AVRDUDE_FLAGS -V                              CACHE STRING "")

if(NOT ARDUINO_FOUND AND ARDUINO_SDK_PATH)
    register_hardware_platform(${ARDUINO_SDK_PATH}/hardware/arduino/)

    find_file(ARDUINO_LIBRARIES_PATH
            NAMES libraries
            PATHS ${ARDUINO_SDK_PATH}
            DOC "Path to directory containing the Arduino libraries."
            NO_SYSTEM_ENVIRONMENT_PATH)

    find_file(ARDUINO_VERSION_PATH
            NAMES lib/version.txt
            PATHS ${ARDUINO_SDK_PATH}
            DOC "Path to Arduino version file."
            NO_SYSTEM_ENVIRONMENT_PATH)

    find_program(ARDUINO_AVRDUDE_PROGRAM
            NAMES avrdude
            PATHS ${ARDUINO_SDK_PATH}
            PATH_SUFFIXES hardware/tools hardware/tools/avr/bin
            NO_DEFAULT_PATH)

    find_program(ARDUINO_AVRDUDE_PROGRAM
            NAMES avrdude
            DOC "Path to avrdude programmer binary.")

    find_program(AVRSIZE_PROGRAM
            NAMES avr-size)

    find_file(ARDUINO_AVRDUDE_CONFIG_PATH
            NAMES avrdude.conf
            PATHS ${ARDUINO_SDK_PATH} /etc/avrdude /etc
            PATH_SUFFIXES hardware/tools
            hardware/tools/avr/etc
            DOC "Path to avrdude programmer configuration file."
            NO_SYSTEM_ENVIRONMENT_PATH)

    if(NOT CMAKE_OBJCOPY)
        find_program(AVROBJCOPY_PROGRAM
                avr-objcopy)
        set(ADDITIONAL_REQUIRED_VARS AVROBJCOPY_PROGRAM)
        set(CMAKE_OBJCOPY ${AVROBJCOPY_PROGRAM} CACHE PATH "OBJCOPY Program for firmware convertion in hex")
    endif(NOT CMAKE_OBJCOPY)

    set(ARDUINO_DEFAULT_BOARD uno  CACHE STRING "Default Arduino Board ID when not specified.")
    set(ARDUINO_DEFAULT_PORT       CACHE STRING "Default Arduino port when not specified.")
    set(ARDUINO_DEFAULT_SERIAL     CACHE STRING "Default Arduino Serial command when not specified.")
    set(ARDUINO_DEFAULT_PROGRAMMER CACHE STRING "Default Arduino Programmer ID when not specified.")

    # Ensure that all required paths are found
    required_variables(VARS
            ARDUINO_PLATFORMS
            ARDUINO_CORES_PATH
            ARDUINO_BOOTLOADERS_PATH
            ARDUINO_LIBRARIES_PATH
            ARDUINO_BOARDS_PATH
            ARDUINO_PROGRAMMERS_PATH
            ARDUINO_VERSION_PATH
            ARDUINO_AVRDUDE_FLAGS
            ARDUINO_AVRDUDE_PROGRAM
            ARDUINO_AVRDUDE_CONFIG_PATH
            AVRSIZE_PROGRAM
            ${ADDITIONAL_REQUIRED_VARS}
            MSG "Invalid Arduino SDK path (${ARDUINO_SDK_PATH}).\n")

    detect_arduino_version(ARDUINO_SDK_VERSION)
    set(ARDUINO_SDK_VERSION       ${ARDUINO_SDK_VERSION}       CACHE STRING "Arduino SDK Version")
    set(ARDUINO_SDK_VERSION_MAJOR ${ARDUINO_SDK_VERSION_MAJOR} CACHE STRING "Arduino SDK Major Version")
    set(ARDUINO_SDK_VERSION_MINOR ${ARDUINO_SDK_VERSION_MINOR} CACHE STRING "Arduino SDK Minor Version")
    set(ARDUINO_SDK_VERSION_PATCH ${ARDUINO_SDK_VERSION_PATCH} CACHE STRING "Arduino SDK Patch Version")

    if(ARDUINO_SDK_VERSION VERSION_LESS 0.19)
        message(FATAL_ERROR "Unsupported Arduino SDK (require version 0.19 or higher)")
    endif()

    message(STATUS "Arduino SDK version ${ARDUINO_SDK_VERSION}: ${ARDUINO_SDK_PATH}")

    setup_arduino_size_script(ARDUINO_SIZE_SCRIPT)
    set(ARDUINO_SIZE_SCRIPT ${ARDUINO_SIZE_SCRIPT} CACHE INTERNAL "Arduino Size Script")

    #print_board_list()
    #print_programmer_list()

    set(ARDUINO_FOUND True CACHE INTERNAL "Arduino Found")
    mark_as_advanced(
            ARDUINO_CORES_PATH
            ARDUINO_VARIANTS_PATH
            ARDUINO_BOOTLOADERS_PATH
            ARDUINO_LIBRARIES_PATH
            ARDUINO_BOARDS_PATH
            ARDUINO_PROGRAMMERS_PATH
            ARDUINO_VERSION_PATH
            ARDUINO_AVRDUDE_FLAGS
            ARDUINO_AVRDUDE_PROGRAM
            ARDUINO_AVRDUDE_CONFIG_PATH
            ARDUINO_OBJCOPY_EEP_FLAGS
            ARDUINO_OBJCOPY_HEX_FLAGS
            AVRSIZE_PROGRAM)
endif()

if(ARDUINO_SDK_VERSION VERSION_LESS 1.5)
    set(ARDUINO_PLATFORM "AVR")
else()
    if(NOT ARDUINO_PLATFORM)
        register_hardware_platform(${ARDUINO_SDK_PATH}/hardware/arduino/avr)
        set(ARDUINO_PLATFORM "AVR")
    else()
        string(TOLOWER ${ARDUINO_PLATFORM} _platform)
        register_hardware_platform(${ARDUINO_SDK_PATH}/hardware/arduino/${_platform})
    endif()
endif()

if(ARDUINO_SDK_VERSION VERSION_LESS 1.5)
    set(ARDUINO_PLATFORM "AVR")
else()
    if(NOT ARDUINO_PLATFORM)
        register_hardware_platform(${ARDUINO_SDK_PATH}/hardware/arduino/avr)
        set(ARDUINO_PLATFORM "AVR")
    else()
        string(TOLOWER ${ARDUINO_PLATFORM} _platform)
        register_hardware_platform(${ARDUINO_SDK_PATH}/hardware/arduino/${_platform})
    endif()
endif()
