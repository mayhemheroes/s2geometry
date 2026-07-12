/*
# Copyright 2020 Google Inc.
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
*/

// Fuzzes s2textformat::MakeIndex over the "points # polylines # polygons" text
// format, then walks the resulting shape index with an S2CellRangeIterator.
// Ported from the original OSS-Fuzz s2_fuzzer to the current upstream API
// (StatusOr MakeIndex; s2shapeutil_range_iterator.h -> s2cell_range_iterator.h).

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <memory>
#include <string>
#include <vector>

#include "absl/status/statusor.h"
#include "absl/strings/str_split.h"
#include "absl/strings/string_view.h"

#include "s2/mutable_s2shape_index.h"
#include "s2/s2cell_range_iterator.h"
#include "s2/s2text_format.h"

// A string-splitter used to help validate the string passed to s2.
static std::vector<absl::string_view> SplitString(absl::string_view str,
                                                  char separator) {
  std::vector<absl::string_view> result =
      absl::StrSplit(str, separator, absl::SkipWhitespace());
  for (auto &e : result) {
    e = absl::StripAsciiWhitespace(e);
  }
  return result;
}

// Do a bit of validation that is also done by s2. We do them here since s2
// would terminate if they would return false inside s2.
static bool isValidFormat(const std::string &nt_string) {
  int hash_count = 0;
  for (char c : nt_string) {
    if (c == '#') {
      hash_count++;
    }
  }
  if (hash_count != 2) {
    return false;
  }

  std::vector<absl::string_view> strs = SplitString(nt_string, '#');
  if (strs.size() != 3) {
    return false;
  }

  return s2textformat::MakeIndex(nt_string).ok();
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 5) {
    return 0;
  }

  std::string nt_string(reinterpret_cast<const char *>(data), size);
  if (isValidFormat(nt_string)) {
    absl::StatusOr<std::unique_ptr<MutableS2ShapeIndex>> index =
        s2textformat::MakeIndex(nt_string);
    if (index.ok()) {
      auto it = MakeS2CellRangeIterator(&**index);
      if (!it.done()) {
        it.Next();
      }
    }
  }
  return 0;
}
