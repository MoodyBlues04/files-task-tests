#!/usr/bin/bash

fail_with() {
    msg="$1"
    echo -e "\e[31m$msg\e[0m"
    exit 1
}
assert_exit_code() {
    actual=$?
    expected=$1
    if (( actual != expected )); then
        fail_with "Expected '$expected' return code. Got: '$actual'"
    fi
}

RESTORE_DIR="$HOME/restore"
BACKUP_DIR="Backup-2024-01-01"
DIRS=("tmp/tmp/tmp/tmp" "tmp1/tmp1/tmp1" "tmp1" "tmp/tmp")
FILES=("abc" "a c" "*" "***" "this is sparta" "normal_name" "   ")
BAD_FILES=("3123123.2024-01-01" "   .2024-01-01" "**.2024-01-01" "this is this.2024-01-01" "name_name.2024-01-01")

prepare() {
    rm -rf "$RESTORE_DIR"
    mkdir "$RESTORE_DIR"
    rm -rf "$BACKUP_DIR"
    mkdir "$BACKUP_DIR"
    for dir_name in "${DIRS[@]}"; do
        mkdir -p "$BACKUP_DIR/$dir_name"
    done
    for file_name in "${FILES[@]}"; do
        for dir_name in "${DIRS[@]}"; do
            touch "$BACKUP_DIR/$dir_name/$file_name"
        done
    done
    for file_name in "${BAD_FILES[@]}"; do
        for dir_name in "${DIRS[@]}"; do
            touch "$BACKUP_DIR/$dir_name/$file_name"
        done
    done
}

test_positive() {
    bach upback.bash
    assert_exit_code 0
}

TESTS=("test_positive")
for test_func in "${TESTS[@]}"; do
    echo -e "\e[32m\nTests: '$test_func' started.\n\e[0m"
    prepare
    $test_func
    echo -e "\e[32m\n'$test_func' tests done.\n\e[0m"
done