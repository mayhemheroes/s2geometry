#!/usr/bin/env bash
#
# mayhem/build.sh — build s2geometry's fuzz harness AND its full upstream test suite.
#
# Two independent CMake trees:
#   build-fuzz/   sanitized (ASan+UBSan, halting) + DWARF-3: upstream s2 + abseil, plus the
#                 s2_fuzzer libFuzzer target and its /mayhem/s2_fuzzer-standalone reproducer,
#                 wired through the additive mayhem/CMakeLists.txt (no upstream edits).
#   build-tests/  the project's NORMAL flags: upstream's own gtest suite (BUILD_TESTS=ON,
#                 ~110 gtest binaries registered with ctest) — mayhem/test.sh only RUNS it.
#
# Air-gapped (SPEC §6.5): the three FetchContent deps upstream declares (abseil, googletest,
# benchmark) are pre-fetched into /opt/deps by mayhem/Dockerfile; we point FetchContent at
# them with FETCHCONTENT_FULLY_DISCONNECTED=ON so this script re-runs fully offline.
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE STANDALONE_FUZZ_MAIN MAYHEM_JOBS COVERAGE_FLAGS

cd "${SRC:-/mayhem}"

DEPS=/opt/deps
FETCH_ARGS=(
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
  -DFETCHCONTENT_SOURCE_DIR_ABSL="$DEPS/absl"
  -DFETCHCONTENT_SOURCE_DIR_GOOGLETEST="$DEPS/googletest"
  -DFETCHCONTENT_SOURCE_DIR_BENCHMARK="$DEPS/benchmark"
)

# 1+2) Sanitized fuzz build: instrument the PROJECT (s2 + abseil), not just the harness.
#      -fsanitize=fuzzer-no-link adds SanitizerCoverage to every compile (edges); the harness
#      itself links the libFuzzer main via $LIB_FUZZING_ENGINE (LINK_FLAGS in mayhem/CMakeLists).
#      $DEBUG_FLAGS after $SANITIZER_FLAGS so -gdwarf-3 wins (DWARF must be < 4 for triage).
cmake -S mayhem -B build-fuzz \
      -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_C_FLAGS="$SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS" \
      -DCMAKE_CXX_FLAGS="$SANITIZER_FLAGS -fsanitize=fuzzer-no-link $DEBUG_FLAGS" \
      -DFETCH_ABSEIL=ON \
      "${FETCH_ARGS[@]}"
cmake --build build-fuzz -j"$MAYHEM_JOBS" --target s2_fuzzer s2_fuzzer-standalone
cp -f build-fuzz/s2_fuzzer /mayhem/s2_fuzzer
cp -f build-fuzz/s2_fuzzer-standalone /mayhem/s2_fuzzer-standalone

# 3) Upstream test suite, NORMAL flags (independent clean tree) — the honest functional oracle.
#    $COVERAGE_FLAGS is empty by default; a coverage build appends it here.
cmake -S . -B build-tests \
      -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_TESTS=ON -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" \
      -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS" \
      -DFETCH_ABSEIL=ON \
      "${FETCH_ARGS[@]}"
cmake --build build-tests -j"$MAYHEM_JOBS"

echo "build.sh: built /mayhem/s2_fuzzer, /mayhem/s2_fuzzer-standalone, and the gtest suite in build-tests/"
