CMAKE_MINIMUM_REQUIRED(VERSION 3.8)
PROJECT(hello LANGUAGES C)

IF (NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  MESSAGE(FATAL_ERROR "
No build type selected. You need to pass --preset=<type> in order to configure CMake project.
")
ENDIF()

SET(CMAKE_C_EXTENSIONS OFF)
SET(CMAKE_C_FLAGS "-std=gnu99 ${CMAKE_C_FLAGS}")

OPTION(USE_SANITIZER "Enable to build with most available sanitizers" OFF)
OPTION(USE_THREAD_SANITIZER "Enable to build with ThreadSanitizer" OFF)

FUNCTION(ADD_EXECUTABLE_WITH_SANITIZER TARGET_NAME FILE_NAME)
  # Create the executable.
  ADD_EXECUTABLE(${TARGET_NAME} ${FILE_NAME})

  # Add basic compile flags.
  TARGET_COMPILE_OPTIONS(${TARGET_NAME} PRIVATE -Wall -Wextra -Wpedantic)

  # Setup sanitizer(s).
  if (USE_SANITIZER)
    TARGET_COMPILE_OPTIONS(${TARGET_NAME} PUBLIC -fsanitize=address,leak,undefined -fno-sanitize-recover=all)
    TARGET_LINK_OPTIONS(${TARGET_NAME} PUBLIC -fsanitize=address,leak,undefined)
  ENDIF()

  IF (USE_THREAD_SANITIZER)
    TARGET_COMPILE_OPTIONS(${TARGET_NAME} PUBLIC -fsanitize=thread -fno-sanitize-recover=all)
    TARGET_LINK_OPTIONS(${TARGET_NAME} PUBLIC -fsanitize=thread)
  ENDIF()
ENDFUNCTION()

ADD_EXECUTABLE_WITH_SANITIZER("hello" "hello.c")
