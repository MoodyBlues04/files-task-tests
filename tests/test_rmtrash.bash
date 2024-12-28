#!/usr/bin/bash

TRASH_DIR=~/.trash
TRASH_LOG=~/.trash.log
FILES=("abc" "a c" "*" "***" "this is sparta" "normal_name" "   ")

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
make_files() {
    for name in "${FILES[@]}"; do
        touch "$name"
        echo "Generated file named '${name}'."
    done
}
rm_files() {
    for name in "${FILES[@]}"; do
        [ -f "$name" ] && rm "$name"
    done
}

test_positive() {
    make_files
    for name in "${FILES[@]}"; do
        bash rmtrash.bash "$name"
        assert_exit_code 0
    done
    for name in "${FILES[@]}"; do
        if [ -f "$name" ]; then
            fail_with "File named '$name' should not exists after removing."
        fi
        trash_dir_files_cnt=$(find $TRASH_DIR -maxdepth 1 -type f | wc -l)
        if (( "${#FILES[@]}" != trash_dir_files_cnt )); then
            fail_with "Trash dir contains: $trash_dir_files_cnt files, expected: ${#FILES[@]}"
        fi
    done

    readarray -t added_lines < <(tail -n ${#FILES[@]} $TRASH_LOG)
    
    for line_idx in "${!added_lines[@]}"; do
        added_line="${added_lines[$line_idx]}"
        expected="$PWD/${FILES[$line_idx]}"
        if [[ "$added_line" != *"$expected"* ]]; then
            fail_with "Line '$added_line' doesnt contain '$expected' as exected."
        fi
    done
}

test_negative_cannot_rm_file() {
    rm_files
    for name in "${FILES[@]}"; do
        bash rmtrash.bash "$name"
        assert_exit_code 1
    done
}

test_negative_cannot_mkdir() {
    make_files
    chmod 400 ~
    for name in "${FILES[@]}"; do
        bash rmtrash.bash "$name"
        assert_exit_code 1
    done
    chmod 744 ~
    rm_files
}

test_negative_cannot_write_to_log() {
    make_files
    chmod 400 $TRASH_LOG
    for name in "${FILES[@]}"; do
        bash rmtrash.bash "$name"
        assert_exit_code 1
    done
    chmod 744 $TRASH_LOG
    rm_files
}

test_negative_missing_params() {
    make_files
    for name in "${FILES[@]}"; do
        bash rmtrash.bash
        assert_exit_code 1
    done
    rm_files
}

TESTS=("test_positive" "test_negative_missing_params" "test_negative_cannot_rm_file" "test_negative_cannot_mkdir" "test_negative_cannot_write_to_log")
for test_func in "${TESTS[@]}"; do
    echo -e "\e[32m\nTests: '$test_func' started.\n\e[0m"
    $test_func
    echo -e "\e[32m\n'$test_func' tests done.\n\e[0m"
done
