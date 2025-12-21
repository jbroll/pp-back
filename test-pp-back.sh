#!/bin/sh
# Test suite for pp-back

. ./Test.sh

# Check SSH localhost availability
ssh_available=0
if ssh -o BatchMode=yes -o ConnectTimeout=2 localhost true 2>/dev/null; then
    ssh_available=1
fi

# Setup test environment
setup() {
    rm -rf test test.ppb test.ppb.exclude
    mkdir -p test/backup test/source
}

# Cleanup
cleanup() {
    rm -rf test test.ppb test.ppb.exclude
}

#
# Test: Retention logic
#
Test "retention: daily/monthly/yearly tiers"

setup
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
link=no
save=5
monthly=2
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

touch test/source/file.txt
result=$(./pp-back -n test 2>&1 | grep "would delete" | awk '{print $3}' | sort | tr '\n' ' ')
expected="2024.0203 2024.0210 2024.0215 2024.0220 2024.0310 2024.0315 2024.0320 2024.0325 2024.0408 2024.0415 2024.0422 "
CompareArgs "$result" "$expected"

#
# Test: Exclude file alongside config
#
Test "exclude: config.ppb.exclude"

setup
mkdir -p test/source/keep test/source/skip
echo "keep" > test/source/keep/file.txt
echo "skip" > test/source/skip/file.txt

cat > test.ppb <<EOF
name=test
mode=pull
host=""
link=no
save=14
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

echo "skip/" > test.ppb.exclude

./pp-back test >/dev/null 2>&1
if [ -d test/backup/*/source/keep ] && [ ! -d test/backup/*/source/skip ]; then
    Pass
else
    Fail
fi

#
# Test: Exclude file in source directory
#
Test "exclude: source/config.ppb.exclude"

setup
mkdir -p test/source/keep test/source/skip
echo "keep" > test/source/keep/file.txt
echo "skip" > test/source/skip/file.txt

cat > test.ppb <<EOF
name=test
mode=pull
host=""
link=no
save=14
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

echo "skip/" > test/source/test.ppb.exclude

./pp-back test >/dev/null 2>&1
if [ -d test/backup/*/source/keep ] && [ ! -d test/backup/*/source/skip ]; then
    Pass
else
    Fail
fi

#
# Test: Hard-link deduplication
#
Test "hardlink: deduplication between backups"

setup
mkdir -p test/source
echo "same content" > test/source/file.txt

cat > test.ppb <<EOF
name=test
mode=pull
host=""
link=yes
save=14
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

./pp-back test >/dev/null 2>&1
first=$(ls -d test/backup/20* | head -1)

# Create second backup (next day simulation)
mv "$first" test/backup/2024.0101
./pp-back test >/dev/null 2>&1
second=$(ls -d test/backup/20* | grep -v 2024.0101 | head -1)

# Check if files share same inode (hard-linked)
inode1=$(stat -c %i "$first/source/file.txt" 2>/dev/null || stat -f %i "$first/source/file.txt")
inode2=$(stat -c %i "$second/source/file.txt" 2>/dev/null || stat -f %i "$second/source/file.txt")

CompareArgs "$inode1" "$inode2"

#
# Test: Delete mode
#
Test "delete: removes files not in source"

setup
mkdir -p test/source test/backup/2024.0101/source
echo "original" > test/source/keep.txt
echo "original" > test/backup/2024.0101/source/keep.txt
echo "deleted" > test/backup/2024.0101/source/remove.txt

cat > test.ppb <<EOF
name=test
mode=pull
host=""
link=yes
save=14
delete=yes
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

./pp-back test >/dev/null 2>&1
today=$(ls -d test/backup/20* | grep -v 2024.0101 | head -1)

if [ -f "$today/source/keep.txt" ] && [ ! -f "$today/source/remove.txt" ]; then
    Pass
else
    Fail
fi

#
# Test: Pre/post backup hooks
#
Test "hooks: ACTION=PRE_BACKUP and POST_BACKUP"

setup
mkdir -p test/source
touch test/source/file.txt

cat > test.ppb <<'OUTER'
name=test
mode=pull
host=""
link=no
save=14
delete=no
prefix=PREFIX_PLACEHOLDER
data="DATA_PLACEHOLDER"

case $ACTION in
    PRE_BACKUP)  echo "pre" >> HOOK_PLACEHOLDER ;;
    POST_BACKUP) echo "post" >> HOOK_PLACEHOLDER ;;
esac
OUTER

sed -i "s|PREFIX_PLACEHOLDER|$(pwd)/test/backup|" test.ppb
sed -i "s|DATA_PLACEHOLDER|$(pwd)/test/source|" test.ppb
sed -i "s|HOOK_PLACEHOLDER|$(pwd)/test/hooks.log|" test.ppb

./pp-back test >/dev/null 2>&1
result=$(cat test/hooks.log 2>/dev/null | tr '\n' ' ')
CompareArgs "$result" "pre post "

#
# Test: Push mode (requires SSH localhost)
#
if [ "$ssh_available" = 1 ]; then
    Test "push: local to remote via SSH localhost"

    setup
    mkdir -p test/source
    echo "push test" > test/source/file.txt

    cat > test.ppb <<EOF
name=test
mode=push
host=localhost
link=no
save=14
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

    ./pp-back test >/dev/null 2>&1
    if [ -f test/backup/*/source/file.txt ]; then
        Pass
    else
        Fail
    fi
else
    echo "SKIP: push mode test (ssh localhost not available)" >&2
fi

#
# Test: Pull mode with remote (requires SSH localhost)
#
if [ "$ssh_available" = 1 ]; then
    Test "pull: remote to local via SSH localhost"

    setup
    mkdir -p test/source
    echo "pull test" > test/source/file.txt

    cat > test.ppb <<EOF
name=test
mode=pull
host=localhost
link=no
save=14
delete=no
prefix=$(pwd)/test/backup
data="$(pwd)/test/source"
EOF

    ./pp-back test >/dev/null 2>&1
    if [ -f test/backup/*/source/file.txt ]; then
        Pass
    else
        Fail
    fi
else
    echo "SKIP: pull remote test (ssh localhost not available)" >&2
fi

cleanup
TestDone
