#!/bin/sh
set -e

# Setup
rm -rf test test.ppb
mkdir -p test/backup test/source
touch test/source/file.txt

cd test/backup
mkdir -p \
    2024.0115 2024.0203 2024.0210 2024.0215 2024.0220 \
    2024.0305 2024.0310 2024.0315 2024.0320 2024.0325 \
    2024.0402 2024.0408 2024.0415 2024.0422 2024.0429 \
    2025.0103 2025.0110 2025.0115 2025.0120 2025.0125
cd ../..

cat > test.ppb <<EOF
name=test
mode=pull
host=""
link=yes
save=5
monthly=2
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

# Run
result=$(./pp-back -n test 2>&1 | grep "would delete" | awk '{print $3}' | sort | tr '\n' ' ')

# Verify
expected="2024.0203 2024.0210 2024.0215 2024.0220 2024.0310 2024.0315 2024.0320 2024.0325 2024.0408 2024.0415 2024.0422 "

if [ "$result" = "$expected" ]; then
    echo "PASS: retention logic correct"
    exit 0
else
    echo "FAIL: retention logic"
    echo "  expected: $expected"
    echo "  got:      $result"
    exit 1
fi
