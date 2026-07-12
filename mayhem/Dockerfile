# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile (SMALL form) for s2geometry — builds on the org C/C++ base.
FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); do NOT bake it as an ENV — an
# empty value breaks clang both here and for any in-image rebuild. build.sh unsets it when empty.
ARG SOURCE_DATE_EPOCH

# Sanitizer override: the base exports SANITIZER_FLAGS (ASan+UBSan, halting) as the default.
# Declared WITHOUT a default so the base ENV flows through when not passed.
ARG SANITIZER_FLAGS
ARG COVERAGE_FLAGS=
ARG MAYHEM_JOBS=

# Air-gap the CMake FetchContent deps (SPEC §6.5): pre-fetch the exact pinned archives that
# upstream CMakeLists.txt declares (abseil 20250814.1, googletest 52eb810, benchmark eddb024)
# into /opt/deps; build.sh points FetchContent at them with FETCHCONTENT_FULLY_DISCONNECTED=ON,
# so mayhem/build.sh re-runs fully offline.
USER root
RUN set -ex \
 && mkdir -p /opt/deps && cd /opt/deps \
 && curl -fsSL -o absl.zip https://github.com/abseil/abseil-cpp/archive/refs/tags/20250814.1.zip \
 && echo "7a56c409044fe02851302fba09fd00c9e06bd8160278f88e51122c76b44b6c00  absl.zip" | sha256sum -c \
 && unzip -q absl.zip && mv abseil-cpp-20250814.1 absl && rm absl.zip \
 && curl -fsSL -o googletest.zip https://github.com/google/googletest/archive/52eb8108c5bdec04579160ae17225d66034bd723.zip \
 && echo "9a56a54ae784394ff664cd55e8f4c9a03b503ebf0cb99576321c78ab3d87ca84  googletest.zip" | sha256sum -c \
 && unzip -q googletest.zip && mv googletest-52eb8108c5bdec04579160ae17225d66034bd723 googletest && rm googletest.zip \
 && curl -fsSL -o benchmark.zip https://github.com/google/benchmark/archive/eddb0241389718a23a42db6af5f0164b6e0139af.zip \
 && echo "6b083b01ee6cb45226f64baa854c48b9ae00ab7a754f0a06f3fb2bae867dd15c  benchmark.zip" | sha256sum -c \
 && unzip -q benchmark.zip && mv benchmark-eddb0241389718a23a42db6af5f0164b6e0139af benchmark && rm benchmark.zip \
 && chown -R 2000:2000 /opt/deps
USER mayhem

# Source enters from the build CONTEXT (the CI checkout): the FULL repo (incl. .git
# history) is copied to /mayhem as `mayhem`; build.sh builds in place.
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

# Run the project's functional tests at build time (a failing suite fails the image build).
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh — repo ships no functional tests"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
