#!/bin/sh
# shellcheck disable=SC1091
# SC1091: Test.sh is external test framework
#
# Test suite for pp-browse

. ./Test.sh

# Check SSH localhost availability
ssh_available=0
if ssh -o BatchMode=yes -o ConnectTimeout=2 localhost true 2>/dev/null; then
    ssh_available=1
fi

# Setup test environment
setup() {
    rm -rf test-browse test-browse.ppb test-browse-push.ppb
    mkdir -p test-browse/backup/2024.0115/home/user
    mkdir -p test-browse/backup/2024.0220/home/user
    mkdir -p test-browse/backup/2025.0101/home/user/docs
    echo "file content" > test-browse/backup/2025.0101/home/user/file.txt
    echo "doc content" > test-browse/backup/2025.0101/home/user/docs/readme.md
    echo '{"key": "value"}' > test-browse/backup/2025.0101/home/user/data.json

    cat > test-browse.ppb <<EOF
name=test-browse
mode=pull
host=""
link=no
save=14
delete=no
prefix=$(pwd)/test-browse/backup
data="$(pwd)/test-browse/source"
EOF
}

# Cleanup
cleanup() {
    rm -rf test-browse test-browse.ppb test-browse-push.ppb
}

# Helper to run pp-browse with given PATH_INFO
run_browse() {
    CONFIG_DIR="$(pwd)" SCRIPT_NAME="/cgi-bin/pp-browse" PATH_INFO="$1" QUERY_STRING="$2" ./pp-browse 2>&1
}

# Extract just the body content (skip headers)
body_only() {
    sed '1,/^$/d'
}

#
# Test: List configs
#
Test "list: shows available configs"

setup
result=$(run_browse "" | grep "test-browse" | grep -c "href")
CompareArgs "$result" "1"

#
# Test: List dates
#
Test "dates: shows backup dates for config"

setup
result=$(run_browse "/test-browse" | grep -E "202[45]\.[0-9]{4}" | grep -c "href")
CompareArgs "$result" "3"

#
# Test: Dates shown in reverse order (newest first)
#
Test "dates: newest first"

setup
result=$(run_browse "/test-browse" | grep -oE "202[45]\.[0-9]{4}" | head -1)
CompareArgs "$result" "2025.0101"

#
# Test: Directory listing
#
Test "browse: lists directory contents"

setup
result=$(run_browse "/test-browse/2025.0101" | grep -c "home")
CompareArgs "$result" "1"

#
# Test: Subdirectory listing
#
Test "browse: lists subdirectory contents"

setup
result=$(run_browse "/test-browse/2025.0101/home/user" | grep "file.txt" | grep -c "href")
CompareArgs "$result" "1"

#
# Test: Back link present
#
Test "browse: shows back/up link"

setup
result=$(run_browse "/test-browse/2025.0101/home/user" | grep -c "Up one level")
CompareArgs "$result" "1"

#
# Test: Download tar link present
#
Test "browse: shows download tar.gz link"

setup
result=$(run_browse "/test-browse/2025.0101/home/user" | grep -c "Download as tar.gz")
CompareArgs "$result" "1"

#
# Test: File download - content
#
Test "file: serves file content"

setup
result=$(run_browse "/test-browse/2025.0101/home/user/file.txt" | body_only)
CompareArgs "$result" "file content"

#
# Test: File download - mime type text/plain
#
Test "file: text/plain mime for .txt"

setup
result=$(run_browse "/test-browse/2025.0101/home/user/file.txt" | grep "Content-Type" | head -1)
CompareArgs "$result" "Content-Type: text/plain"

#
# Test: File download - mime type application/json
#
Test "file: application/json mime for .json"

setup
result=$(run_browse "/test-browse/2025.0101/home/user/data.json" | grep "Content-Type" | head -1)
CompareArgs "$result" "Content-Type: application/json"

#
# Test: File download - mime type text/plain for .md
#
Test "file: text/plain mime for .md"

setup
result=$(run_browse "/test-browse/2025.0101/home/user/docs/readme.md" | grep "Content-Type" | head -1)
CompareArgs "$result" "Content-Type: text/plain"

#
# Test: Tar download - headers
#
Test "tar: correct headers for directory download"

setup
result=$(run_browse "/test-browse/2025.0101/home/user" "tar" | grep "Content-Type" | head -1)
CompareArgs "$result" "Content-Type: application/gzip"

#
# Test: Tar download - filename header
#
Test "tar: correct filename in disposition"

setup
result=$(run_browse "/test-browse/2025.0101/home/user" "tar" | grep "Content-Disposition")
case "$result" in
    *'filename="user.tar.gz"'*) Pass ;;
    *) Fail ;;
esac

#
# Test: Tar download - valid gzip
#
Test "tar: produces valid gzip output"

setup
if run_browse "/test-browse/2025.0101/home/user" "tar" | body_only | gzip -t 2>/dev/null; then
    Pass
else
    Fail
fi

#
# Test: Tar download - contains expected files
#
Test "tar: archive contains expected files"

setup
result=$(run_browse "/test-browse/2025.0101/home/user" "tar" | body_only | tar -tzf - 2>/dev/null | grep -c "file.txt")
CompareArgs "$result" "1"

#
# Test: Tar download at date level
#
Test "tar: download entire date backup"

setup
result=$(run_browse "/test-browse/2025.0101" "tar" | grep "Content-Disposition")
case "$result" in
    *'filename="test-browse-2025.0101.tar.gz"'*) Pass ;;
    *) Fail ;;
esac

#
# Test: Security - path traversal rejected
#
Test "security: rejects path traversal"

setup
result=$(run_browse "/test-browse/2025.0101/../../../etc/passwd" | grep -c "400 Bad Request")
CompareArgs "$result" "1"

#
# Test: Security - invalid config name rejected
#
Test "security: rejects invalid config name"

setup
result=$(run_browse "/test;rm -rf/" | grep -c "400 Bad Request")
CompareArgs "$result" "1"

#
# Test: Security - invalid date format rejected
#
Test "security: rejects invalid date format"

setup
result=$(run_browse "/test-browse/notadate" | grep -c "400 Bad Request")
CompareArgs "$result" "1"

#
# Test: Security - config with spaces rejected
#
Test "security: rejects config with spaces"

setup
result=$(run_browse "/test browse" | grep -c "400 Bad Request")
CompareArgs "$result" "1"

#
# Test: 404 for missing file
#
Test "error: 404 for missing file"

setup
result=$(run_browse "/test-browse/2025.0101/home/user/nonexistent.txt" | grep -c "404 Not Found")
CompareArgs "$result" "1"

#
# Test: 404 for missing config
#
Test "error: 404 for missing config"

setup
result=$(run_browse "/nonexistent" | grep -c "404 Not Found")
CompareArgs "$result" "1"

#
# Test: Push mode via SSH localhost
#
if [ "$ssh_available" = 1 ]; then
    Test "push: browse remote via SSH localhost"

    setup
    cat > test-browse-push.ppb <<EOF
name=test-browse-push
mode=push
host=localhost
link=no
save=14
delete=no
prefix=$(pwd)/test-browse/backup
data="$(pwd)/test-browse/source"
EOF

    result=$(run_browse "/test-browse-push/2025.0101/home/user" | grep "file.txt" | grep -c "href")
    CompareArgs "$result" "1"

    Test "push: serve file via SSH localhost"

    result=$(run_browse "/test-browse-push/2025.0101/home/user/file.txt" | body_only)
    CompareArgs "$result" "file content"

    Test "push: tar download via SSH localhost"

    result=$(run_browse "/test-browse-push/2025.0101/home/user" "tar" | body_only | tar -tzf - 2>/dev/null | grep -c "file.txt")
    CompareArgs "$result" "1"
else
    echo "SKIP: push mode tests (ssh localhost not available)" >&2
fi

#
# Test: Server mode (requires python3 and curl)
#
python3_available=0
curl_available=0
if command -v python3 >/dev/null 2>&1; then
    python3_available=1
fi
if command -v curl >/dev/null 2>&1; then
    curl_available=1
fi

if [ "$python3_available" = 1 ] && [ "$curl_available" = 1 ]; then
    # Use a random-ish port to avoid conflicts
    server_port=$((8900 + $$ % 100))

    # Helper to start server with correct CONFIG_DIR
    start_server() {
        CONFIG_DIR="$(pwd)" ./pp-browse "$server_port" >/dev/null 2>&1 &
        server_pid=$!
        sleep 2
    }

    stop_server() {
        kill $server_pid 2>/dev/null
        wait $server_pid 2>/dev/null
    }

    Test "server: starts and lists configs"

    setup
    start_server
    result=$(curl -s --max-time 3 "http://localhost:$server_port/cgi-bin/pp-browse" | grep -c "test-browse")
    stop_server
    CompareArgs "$result" "1"

    Test "server: lists backup dates"

    setup
    start_server
    result=$(curl -s --max-time 3 "http://localhost:$server_port/cgi-bin/pp-browse/test-browse" | grep -c "2025.0101")
    stop_server
    CompareArgs "$result" "1"

    Test "server: serves file content"

    setup
    start_server
    result=$(curl -s --max-time 3 "http://localhost:$server_port/cgi-bin/pp-browse/test-browse/2025.0101/home/user/file.txt")
    stop_server
    CompareArgs "$result" "file content"

    Test "server: tar download works"

    setup
    start_server
    result=$(curl -s --max-time 3 "http://localhost:$server_port/cgi-bin/pp-browse/test-browse/2025.0101/home/user?tar" | tar -tzf - 2>/dev/null | grep -c "file.txt")
    stop_server
    CompareArgs "$result" "1"
else
    echo "SKIP: server mode tests (python3 or curl not available)" >&2
fi

cleanup
TestDone
