# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################

FROM gcr.io/oss-fuzz-base/base-builder
RUN for i in 1 2 3 4 5; do \
      apt-get update --fix-missing && \
      apt-get -y install --fix-missing libgflags-dev libgoogle-glog-dev libgtest-dev libssl-dev make curl pkg-config && break || \
      { echo "Attempt $i failed, retrying..."; sleep 10; }; \
    done

# OpenSSL
ARG OPENSSL_VERSION=1.1.1w
ARG OPENSSL_HASH=cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8
RUN set -ex && curl -sL https://github.com/openssl/openssl/releases/download/OpenSSL_1_1_1w/openssl-${OPENSSL_VERSION}.tar.gz -o openssl-${OPENSSL_VERSION}.tar.gz && echo "${OPENSSL_HASH} openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz && cd openssl-${OPENSSL_VERSION} && ./Configure linux-x86_64 no-shared --static "$CFLAGS" && make build_generated && make libcrypto.a && make install

COPY . s2geometry
RUN rm -rf s2geometry/mayhem
WORKDIR $SRC/s2geometry
COPY mayhem/build.sh mayhem/s2_fuzzer.cc $SRC/
COPY mayhem/project.patch $SRC/

ENV FUZZING_LANGUAGE=c++ SANITIZER=address
RUN compile
