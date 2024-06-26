// Copyright Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS-IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#include "s2/s2shapeutil_edge_iterator.h"

#include <string>

#include "absl/log/absl_check.h"
#include "absl/strings/str_cat.h"
#include "s2/s2shape.h"
#include "s2/s2shape_index.h"

using std::string;

namespace s2shapeutil {

EdgeIterator::EdgeIterator(const S2ShapeIndex* index) : index_(index) {
  Next();
}

S2Shape::Edge EdgeIterator::edge() const {
  ABSL_DCHECK(!Done());
  return index_->shape(shape_id_)->edge(edge_id_);
}

void EdgeIterator::Next() {
  while (++edge_id_ >= num_edges_) {
    if (++shape_id_ >= index_->num_shape_ids()) break;
    const S2Shape* shape = index_->shape(shape_id_);
    num_edges_ = (shape == nullptr) ? 0 : shape->num_edges();
    edge_id_ = -1;
  }
}

string EdgeIterator::DebugString() const {
  return absl::StrCat("(shape=", shape_id_, ", edge=", edge_id_, ")");
}

}  // namespace s2shapeutil
