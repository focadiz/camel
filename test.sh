#!/usr/bin/env bash
#
# Local dev helper: get a clean `mvn test` run on this machine.
#
# Notes (from diagnosing failures on this machine):
# - `mvn test` alone from an empty/stale ~/.m2 fails: several modules need
#   artifacts (e.g. sources jars) only produced up to the `install` phase.
# - camel-exec's tests require JAVA_HOME to be set.
# - camel-sql's embedded-MariaDB test needs libcrypt.so.1 (install
#   libxcrypt-compat on Arch: `sudo pacman -S libxcrypt-compat`).
# - camel-djl is excluded: its bundled PyTorch native lib needs AVX2, which
#   this CPU doesn't support (crashes with SIGILL). Likely fine on other
#   hardware.
# - camel-jbang-core and camel-jbang-plugin-kubernetes are excluded: their
#   export tests need camel-catalog-provider-springboot:4.23.0-SNAPSHOT from
#   the separate apache/camel-spring-boot repo, which isn't available here.

set -euo pipefail

cd "$(dirname "$0")"

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-26-openjdk}"
export JAVA_HOME

if ! ldconfig -p | grep -q 'libcrypt\.so\.1'; then
    echo "WARNING: libcrypt.so.1 not found. camel-sql's embedded MariaDB test needs it." >&2
    echo "Install with: sudo pacman -S libxcrypt-compat" >&2
fi

# 1. Populate the local Maven repo (sources jars, etc. that plain `test` won't produce).
mvn clean install -Dquickly

# 2. Run the tests, skipping modules that can't pass on this machine (see notes above).
mvn test -pl '!components/camel-ai/camel-djl,!dsl/camel-jbang/camel-jbang-core,!dsl/camel-jbang/camel-jbang-plugin-kubernetes'
