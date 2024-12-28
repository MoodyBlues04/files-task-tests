#!/usr/bin/bash

RESTORE_DIR="$HOME/restore"
BACKUP_DIR="$HOME/Backup-2024-10-10"
DIRS=("tmp/tmp/tmp/tmp" "tmp1/tmp1/tmp1" "tmp1" "tmp/tmp" "*/*/*" "**/*" "*/     /*")
FILES=("abc" "a c" "*" "***" "this is sparta" "normal_name" "   ")
BAD_FILES=("3123123.2024-01-01" "   .2024-01-01" "**.2024-01-01" "this is this.2024-01-01" "name_name.2024-01-01")

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

prepare() {
    rm -rf "$RESTORE_DIR"
    # mkdir "$RESTORE_DIR"
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
    bash upback.bash
    assert_exit_code 0

    if [ ! -d "$RESTORE_DIR" ]; then
        fail_with "Restore dir not created."
    fi
    for dir_name in "${DIRS[@]}"; do
        for file_name in "${FILES[@]}"; do
            backup_path="$BACKUP_DIR/$dir_name/$file_name"
            cmp --silent "$backup_path" "$RESTORE_DIR/$dir_name/$file_name" || fail_with "Not backup file: '$backup_path'."
        done
        for file_name in "${BAD_FILES[@]}"; do
            restore_path="$RESTORE_DIR/$dir_name/$file_name"
            [ -f "$restore_path" ] && fail_with "Unexpected to backup file with extension: '$restore_path'."
        done
    done
}

test_positive_many_backups() {
    prev_backups=("$HOME/Backup-2024-09-09" "$HOME/Backup-2024-08-08" "$HOME/Backup-2024-09-07")
    for prev_backup in "${prev_backups[@]}"; do
        mkdir -p "$prev_backup"
    done
    test_positive
    for prev_backup in "${prev_backups[@]}"; do
        rm -rf "$prev_backup"
    done
}

test_negative_no_backup_dirs() {
    while read -r backup_dir; do
        rm -rf "$backup_dir"
    done < <(find ~ -maxdepth 1 -type d -regex .*Backup.*)
    bash upback.bash
    assert_exit_code 1
}

test_negative_cannot_write_to_restore() {
    mkdir -p "$RESTORE_DIR"
    chmod 000 "$RESTORE_DIR"
    bash upback.bash
    assert_exit_code 1
    chmod 744 "$RESTORE_DIR"
}

test_negative_cannot_rw_backup() {
    chmod 000 "$BACKUP_DIR"
    bash upback.bash
    assert_exit_code 1
    chmod 744 "$BACKUP_DIR"
}

TESTS=("test_positive" "test_positive_many_backups"
    "test_negative_no_backup_dirs" "test_negative_cannot_write_to_restore" "test_negative_cannot_rw_backup")
for test_func in "${TESTS[@]}"; do
    echo -e "\e[32m\nTests: '$test_func' started.\n\e[0m"
    prepare
    $test_func
    echo -e "\e[32m\n'$test_func' tests done.\n\e[0m"
done
