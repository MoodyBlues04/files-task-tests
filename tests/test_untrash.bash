#!/usr/bin/bash

TMP_DIR=~/.tmp
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
get_filename_version() {
    filename="$1"
    echo "$filename" | grep -o -P "\\([0-9]+\\)((\\.[a-zA-Z]+)+)?$" | grep -o -P "[0-9]+"
}

prepare() {
    rm -rf $TRASH_DIR
    mkdir $TRASH_DIR
    rm -rf $TMP_DIR
    mkdir -p $TMP_DIR
    :> $TRASH_LOG
}
files_cnt=1
put_to_trash() {
    filename="$1"
    touch $TRASH_DIR/"${filename}_$files_cnt"
    echo $TMP_DIR/"$filename ${filename}_$files_cnt" >> $TRASH_LOG
    ((files_cnt++))
}

test_positive_no_conflict() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        bash untrash.bash "$name" <<< Y
        assert_exit_code 0
        if [ ! -f $TMP_DIR"/$name" ]; then
            fail_with "File named '$name' doesnt appear after untrash."
        fi
        trash_dir_files_cnt=$(find $TRASH_DIR -maxdepth 1 -type f | wc -l)
        if ((0 != trash_dir_files_cnt)); then
            fail_with "File named '$name' should be removed from .trash after untrash."
        fi
        log_line=$(tail -n 1 $TRASH_LOG)
        if [[ "$log_line" == "*$name*" ]]; then
            fail_with "Log file must not contain untrashed file '$name'."
        fi
    done
}

test_positive_no_conflict_restore_at_home() {
    rm -rf $TMP_DIR
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        bash untrash.bash "$name" <<< Y
        assert_exit_code 0
        if [ ! -f "$HOME/$name" ]; then
            fail_with "File named '$name' doesnt appear after untrash."
        fi
        rm "$HOME/$name" # not to keep waste
        trash_dir_files_cnt=$(find $TRASH_DIR -maxdepth 1 -type f | wc -l)
        if ((0 != trash_dir_files_cnt)); then
            fail_with "File named '$name' should be removed from .trash after untrash."
        fi
        log_line=$(tail -n 1 $TRASH_LOG)
        if [[ "$log_line" == "*$name*" ]]; then
            fail_with "Log file must not contain untrashed file '$name'."
        fi
    done
}

test_positive_same_names() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name" && put_to_trash "$name" && put_to_trash "$name"
        bash untrash.bash "$name" <<< NNY
        assert_exit_code 0
    done
}

test_positive_with_conflict_ignore() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        timestamp=$(date +%s)
        echo "$timestamp" > $TMP_DIR"/$name" # to ensure, that file wasnt replaced
        bash untrash.bash -i "$name" <<< Y
        assert_exit_code 0
        if [[ ! -f $TMP_DIR"/$name" ]]; then
            fail_with "File named '$name' doesnt appear after untrash."
        fi
        if [[ "$timestamp" != $(cat $TMP_DIR"/$name") ]]; then
            fail_with "File must not be replaced when --ignore option enabled. File: '$name'."
        fi
        trash_dir_files_cnt=$(find $TRASH_DIR -maxdepth 1 -type f | wc -l)
        if ((0 != trash_dir_files_cnt)); then
            fail_with "File named '$name' should be removed from .trash after untrash."
        fi
        log_line=$(tail -n 1 $TRASH_LOG)
        if [[ "$log_line" == "*$name*" ]]; then
            fail_with "Log file must not contain untrashed file '$name'."
        fi
    done
}

test_positive_with_conflict_overwrite() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        timestamp=$(date +%s)
        echo "$timestamp" > $TMP_DIR"/$name" # to ensure, that file was replaced
        bash untrash.bash -o "$name" <<< Y
        assert_exit_code 0
        if [[ ! -f $TMP_DIR"/$name" ]]; then
            fail_with "File named '$name' doesnt appear after untrash."
        fi
        if [[ "$timestamp" == $(cat $TMP_DIR"/$name") ]]; then
            fail_with "File must be replaced when --overwrite option enabled. File: '$name'."
        fi
        trash_dir_files_cnt=$(find $TRASH_DIR -maxdepth 1 -type f | wc -l)
        if ((0 != trash_dir_files_cnt)); then
            fail_with "File named '$name' should be removed from .trash after untrash."
        fi
        log_line=$(tail -n 1 $TRASH_LOG)
        if [[ "$log_line" == "*$name*" ]]; then
            fail_with "Log file must not contain untrashed file '$name'."
        fi
    done
}

test_positive_with_conflict_unique() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        timestamp=$(date +%s)
        echo "$timestamp" > $TMP_DIR"/$name" # to ensure, that file wasnt replaced
        bash untrash.bash -u "$name" <<< Y
        assert_exit_code 0
        if [[ ! -f $TMP_DIR"/$name" ]]; then
            fail_with "File named '$name' doesnt appear after untrash."
        fi
        if [[ "$timestamp" != $(cat $TMP_DIR"/$name") ]]; then
            fail_with "File must not be replaced when --unique option enabled. File: '$name'."
        fi
        trash_dir_files_cnt=$(find $TRASH_DIR -maxdepth 1 -type f | wc -l)
        if ((0 != trash_dir_files_cnt)); then
            fail_with "File named '$name' should be removed from .trash after untrash."
        fi
        log_line=$(tail -n 1 $TRASH_LOG)
        if [[ "$log_line" == "*$name*" ]]; then
            fail_with "Log file must not contain untrashed file '$name'."
        fi

        # check version
        # если сделать хорошее получение extension и version - это можно будет скопировать себе в решение всем))
        file_version=$(get_filename_version "$name")
        if [ -z "$file_version" ]; then
            file_version=0
        fi
        ((file_version++))
        expected_name="$name($file_version)"
        if [[ ! -f $TMP_DIR"/$expected_name" ]]; then
            fail_with "Expected file with version: '$expected_name' to be created."
        fi
    done
}

test_negative_no_log() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        rm $TRASH_LOG
        bash untrash.bash "$name" <<< Y
        assert_exit_code 1
    done
}

test_negative_no_trash_dir() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        rm -rf $TRASH_DIR
        bash untrash.bash "$name" <<< Y
        assert_exit_code 1
    done
}

test_negative_file_not_in_trash_log() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        sed -i '$d' $TRASH_LOG
        bash untrash.bash "$name" <<< Y
        assert_exit_code 1
    done
}

test_negative_file_not_in_trash_dir() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        rm $TRASH_DIR/*"$name"*
        bash untrash.bash "$name" <<< Y
        assert_exit_code 1
    done
}

test_negative_cannot_make_ln() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        chmod 000 $TMP_DIR
        bash untrash.bash "$name" <<< Y
        assert_exit_code 1
        chmod 744 $TMP_DIR
    done
}

test_negative_invalid_options() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        bash untrash.bash -w "$name" <<< Y
        assert_exit_code 1
    done
}

test_negative_invalid_no_args() {
    for name in "${FILES[@]}"; do
        put_to_trash "$name"
        bash untrash.bash -w <<< Y
        assert_exit_code 1
    done
}

TESTS=("test_positive_no_conflict" "test_positive_no_conflict_restore_at_home" "test_positive_same_names" "test_negative_no_log"
    "test_negative_no_trash_dir" "test_negative_file_not_in_trash_log" "test_negative_file_not_in_trash_dir" "test_negative_cannot_make_ln"
    "test_negative_invalid_options" "test_negative_invalid_no_args"
    "test_positive_with_conflict_ignore" "test_positive_with_conflict_overwrite" "test_positive_with_conflict_unique")
for test_func in "${TESTS[@]}"; do
    echo -e "\e[32m\nTests: '$test_func' started.\n\e[0m"
    prepare
    $test_func
    echo -e "\e[32m\n'$test_func' tests done.\n\e[0m"
done
