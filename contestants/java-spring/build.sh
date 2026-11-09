#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mvn -q -B -DskipTests package
cp target/notes-1.0.0.jar app.jar
{ java -version 2>&1 | head -1; grep -A2 'spring-boot-starter-parent' pom.xml | grep version; grep -A2 'sqlite-jdbc' pom.xml | grep version; } > versions.txt
rm -rf target
