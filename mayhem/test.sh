#!/usr/bin/env bash
#
# mayhem/test.sh — RUN s2geometry's full upstream gtest suite (built by mayhem/build.sh in
# build-tests/, BUILD_TESTS=ON → gtest_discover_tests via ctest) and report CTRF counts.
# Behavioral oracle: gtest asserts computed geometry values (known-answer tests), and the
# guard below additionally requires a real gtest "[  PASSED  ]" report from a test binary —
# a program neutered to exit(0) produces no gtest output and FAILS here.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "${SRC:-/mayhem}"

emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Do NOT build here — build.sh produced the suite. Fail loudly if it's missing.
if [ ! -f build-tests/CTestTestfile.cmake ]; then
  echo "test.sh: build-tests/ missing — mayhem/build.sh did not build the test suite" >&2
  emit_ctrf "cmake-ctest" 0 1
  exit 1
fi

# Behavioral guard (anti-reward-hack): a gtest binary must actually RUN its tests and print a
# non-zero "[  PASSED  ] N" report. A binary sabotaged to _exit(0) prints nothing and fails this.
guard_failed=0
guard_bin="$(find build-tests -maxdepth 1 -name 's2latlng_test' -type f | head -1)"
if [ -z "$guard_bin" ]; then
  echo "test.sh: guard binary s2latlng_test missing from build-tests/" >&2
  guard_failed=1
else
  guard_out="$("$guard_bin" 2>&1 || true)"
  guard_n="$(printf '%s\n' "$guard_out" | sed -n 's/^\[  PASSED  \] \([0-9][0-9]*\) tests\?.*/\1/p' | head -1)"
  if [ -z "$guard_n" ] || [ "$guard_n" -eq 0 ]; then
    echo "test.sh: behavioral guard FAILED — s2latlng_test produced no gtest PASSED report" >&2
    guard_failed=1
  fi
fi

# Run the ENTIRE upstream suite via ctest.
ctest_rc=0
(cd build-tests && ctest -j"$MAYHEM_JOBS" --output-on-failure) > /tmp/ctest.log 2>&1 || ctest_rc=$?
tail -20 /tmp/ctest.log

# Parse: "100% tests passed, 0 tests failed out of 1234"
summary_line="$(grep -E 'tests passed, .* tests failed out of' /tmp/ctest.log | tail -1)"
total="$(printf '%s\n' "$summary_line" | sed -n 's/.*out of \([0-9][0-9]*\).*/\1/p')"
failed="$(printf '%s\n' "$summary_line" | sed -n 's/.*, \([0-9][0-9]*\) tests failed out of.*/\1/p')"
if [ -z "$total" ] || [ -z "$failed" ]; then
  echo "test.sh: could not parse ctest summary (ctest rc=$ctest_rc)" >&2
  emit_ctrf "cmake-ctest" 0 1
  exit 1
fi
passed=$(( total - failed ))
failed=$(( failed + guard_failed ))

emit_ctrf "cmake-ctest" "$passed" "$failed"
