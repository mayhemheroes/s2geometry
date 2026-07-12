# Additive fuzz-harness project: builds upstream s2geometry (via add_subdirectory) plus the
# s2_fuzzer libFuzzer target and its run-once standalone reproducer, without editing any
# upstream file. Configured by mayhem/build.sh with -S mayhem.
cmake_minimum_required(VERSION 3.22)
project(s2geometry-mayhem C CXX)

set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON CACHE BOOL "" FORCE)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/.. ${CMAKE_CURRENT_BINARY_DIR}/s2)

set(S2_FUZZ_LIBS
    s2
    absl::base
    absl::btree
    absl::core_headers
    absl::flags_reflection
    absl::memory
    absl::span
    absl::str_format
    absl::strings
    absl::utility
    absl::synchronization)

add_executable(s2_fuzzer s2_fuzzer.cc)
target_link_libraries(s2_fuzzer ${S2_FUZZ_LIBS})
set_target_properties(s2_fuzzer PROPERTIES LINK_FLAGS "$ENV{LIB_FUZZING_ENGINE}")

# Standalone (non-fuzzer) run-once reproducer: same harness linked against LLVM's
# StandaloneFuzzTargetMain.c (compiled as C so LLVMFuzzerTestOneInput keeps C linkage).
add_library(standalone_fuzz_main OBJECT "$ENV{STANDALONE_FUZZ_MAIN}")
set_source_files_properties("$ENV{STANDALONE_FUZZ_MAIN}" PROPERTIES LANGUAGE C)
add_executable(s2_fuzzer-standalone s2_fuzzer.cc $<TARGET_OBJECTS:standalone_fuzz_main>)
target_link_libraries(s2_fuzzer-standalone ${S2_FUZZ_LIBS})
