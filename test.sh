#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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
# - camel-printer is excluded: PrinterPrintTest fails with
#   ArrayIndexOutOfBoundsException because PrintServiceLookup.lookupPrintServices()
#   returns no print services on this machine (no printer/print service configured).
# - `-T 16` (parallel reactor build) brought total time down to ~18 minutes on
#   this machine, vs. ~1 hour single-threaded. Most modules are independent, so
#   this parallelizes well; watch for new failures that only show up under
#   parallelism (usually real test-isolation bugs: shared ports/temp dirs).

set -euo pipefail

cd "$(dirname "$0")"

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-26-openjdk}"
export JAVA_HOME

if ! ldconfig -p | grep -q 'libcrypt\.so\.1'; then
    echo "WARNING: libcrypt.so.1 not found. camel-sql's embedded MariaDB test needs it." >&2
    echo "Install with: sudo pacman -S libxcrypt-compat" >&2
fi

# 1. Populate the local Maven repo (sources jars, etc. that plain `test` won't produce).
mvn clean install -Dquickly -T 16

# 2. Run the tests, skipping modules that can't pass on this machine (see notes above).
mvn test -T 16 -DargLine="-Xmx16g" -pl '!components/camel-ai/camel-djl,!dsl/camel-jbang/camel-jbang-core,!dsl/camel-jbang/camel-jbang-plugin-kubernetes,!components/camel-printer'
