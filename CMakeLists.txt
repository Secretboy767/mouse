cmake_minimum_required(VERSION 3.20)
project(MemoryCore VERSION 1.0.0 LANGUAGES CXX)

include(CTest)

add_library(memorycore SHARED
    Native/MemoryCore.cpp
)
target_compile_features(memorycore PUBLIC cxx_std_20)
target_include_directories(memorycore PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Native>
    $<INSTALL_INTERFACE:include>
)
target_compile_options(memorycore PRIVATE -Wall -Wextra -Wpedantic -Wconversion)
set_target_properties(memorycore PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
)

if(BUILD_TESTING)
    add_executable(memorycore_tests Tests/MemoryCoreTests.cpp)
    target_compile_features(memorycore_tests PRIVATE cxx_std_20)
    target_link_libraries(memorycore_tests PRIVATE memorycore)
    add_test(NAME memorycore_tests COMMAND memorycore_tests)
endif()
