#!/bin/bash -eu
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

cp $SRC/s2_fuzzer.cc $SRC/s2geometry/src/

cd $SRC/
git clone --depth=1 --branch lts_2023_01_25 https://github.com/abseil/abseil-cpp
cd abseil-cpp
mkdir build && cd build
cmake -DCMAKE_POSITION_INDEPENDENT_CODE=ON ../  && make && make install

cd $SRC/s2geometry

# Append the fuzzer target directly (instead of applying the patch which may fail on updated CMakeLists)
cat >> CMakeLists.txt << 'CMAKELISTS_PATCH'

add_executable(s2fuzzer src/s2_fuzzer.cc)
set_target_properties(s2fuzzer PROPERTIES LINK_FLAGS $ENV{LIB_FUZZING_ENGINE})
target_link_libraries(
  s2fuzzer
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
CMAKELISTS_PATCH

mkdir build && cd build

cmake -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_TESTS=OFF \
      -DABSL_MIN_LOG_LEVEL=4 ..
make -j$(nproc)
find . -name "s2fuzzer" -exec cp {} $OUT/s2_fuzzer \;
