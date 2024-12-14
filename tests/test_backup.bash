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
escape_string() {
    str="$1"
    echo "${str//[\.\^\$\*\+\?\(\)\[\]\{\}\|\\\\]/\\&}"
}

SOURCE_DIR="$HOME/source"
REPORT_FILE="$HOME/backup-report"

DIRS=("tmp/tmp/tmp/tmp" "tmp1/tmp1/tmp1" "tmp1" "tmp/tmp")
FILES=("abc" "a c" "*" "***" "this is sparta" "normal_name" "   ")

prepare() {
    :> "$REPORT_FILE"
    chmod -R 744 "$SOURCE_DIR"
    rm -rf "$SOURCE_DIR"
    mkdir "$SOURCE_DIR"
    for dir_name in "${DIRS[@]}"; do
        mkdir -p "$SOURCE_DIR/$dir_name"
    done
    for file_name in "${FILES[@]}"; do
        for dir_name in "${DIRS[@]}"; do
            touch "$SOURCE_DIR/$dir_name/$file_name"
        done
    done
    while read -r backup_dir; do
        rm -rf "$backup_dir"
    done < <(find ~ -maxdepth 1 -type d | grep -E "Backup\\-[0-9]{4}\\-[0-9]{2}\\-[0-9]{2}$")
}

test_positive_new_backup() {
    cur_date=$(date '+%Y-%m-%d')
    backup_dir="Backup-$cur_date"
    backup_dir_path="$HOME/$backup_dir"
    bash backup.bash
    assert_exit_code 0
    if [ ! -d "$backup_dir_path" ]; then
        fail_with "Backup dir not created."
    fi
    for dir_name in "${DIRS[@]}"; do
        for file_name in "${FILES[@]}"; do
            source_path="$SOURCE_DIR/$dir_name/$file_name"
            cmp --silent "$source_path" "$backup_dir_path/$dir_name/$file_name" || fail_with "Not backup file: '$source_path'."
        done
    done

    readarray -t report_lines < "$REPORT_FILE"
    lines_cnt=${#report_lines[@]}
    dir_cnt=${#DIRS[@]}
    files_cnt=${#FILES[@]}
    total_cnt=$(( dir_cnt * files_cnt ))
    if (( lines_cnt != total_cnt + 1 )); then
        fail_with "Expected files count in report to equal: '$(( total_cnt + 1 ))' after creating '$total_cnt' files. Got: '$lines_cnt' lines."
    fi
    for dir_name in "${DIRS[@]}"; do
        for file_name in "${FILES[@]}"; do
            path="$dir_name/$file_name"
            if [[ ! " ${report_lines[*]} " =~ [[:space:]]${path}[[:space:]] ]]; then
                fail_with "Not found path: '$path' in report file."
            fi
        done
    done
}

test_positive_update_backup_only_new_files() {
    cur_date=$(date '+%Y-%m-%d')
    backup_dir="Backup-$cur_date"
    backup_dir_path="$HOME/$backup_dir"
    bash backup.bash
    assert_exit_code 0
    if [ ! -d "$backup_dir_path" ]; then
        fail_with "Backup dir not created."
    fi
    
    extra_files=("tmp/tmp/12345" "tmp/1234" "tmp1/tmp1/abc")
    for file_name in "${extra_files[@]}"; do
        mkdir -p "$( dirname "$SOURCE_DIR/$file_name" )"
        touch "$SOURCE_DIR/$file_name"
    done
    
    :> "$REPORT_FILE" # to get output only about updated files
    
    bash backup.bash
    assert_exit_code 0

    lines_cnt=${#extra_files[@]}
    readarray -t report_lines < <(tail -n "$lines_cnt" "$REPORT_FILE")
    dir_cnt=${#DIRS[@]}
    files_cnt=${#FILES[@]}
    total_cnt=$(( dir_cnt * files_cnt ))
    for file_name in "${extra_files[@]}"; do
        if [[ ! " ${report_lines[*]} " =~ [[:space:]]${file_name}[[:space:]] ]]; then
            fail_with "Not found path: '$file_name' in report file."
        fi
    done
}

test_positive_update_backup_update_files() {
    cur_date=$(date '+%Y-%m-%d')
    backup_dir="Backup-$cur_date"
    backup_dir_path="$HOME/$backup_dir"
    bash backup.bash
    assert_exit_code 0
    if [ ! -d "$backup_dir_path" ]; then
        fail_with "Backup dir not created."
    fi

    timestamp=$(date +%s)
    for dir_name in "${DIRS[@]}"; do
        for file_name in "${FILES[@]}"; do
            source_path="$SOURCE_DIR/$dir_name/$file_name"
            echo "new text. $timestamp" >> "$source_path"
        done
    done

    :> "$REPORT_FILE"

    bash backup.bash
    assert_exit_code 0

    readarray -t report_lines < "$REPORT_FILE"
    lines_cnt=${#report_lines[@]}
    dir_cnt=${#DIRS[@]}
    files_cnt=${#FILES[@]}
    total_cnt=$(( dir_cnt * files_cnt ))
    if (( lines_cnt != total_cnt + 1 )); then
        fail_with "Expected files count in report to equal: '$(( total_cnt + 1 ))' after updating '$total_cnt' files. Got: '$lines_cnt' lines."
    fi
    for dir_name in "${DIRS[@]}"; do
        for file_name in "${FILES[@]}"; do
            expected_line="$dir_name/$file_name $dir_name/$file_name.$cur_date"
            escaped=$(escape_string "$expected_line")
            if [[ ! " ${report_lines[*]} " =~ [[:space:]]${escaped}[[:space:]] ]]; then
                fail_with "Not found updated info: '$expected_line' in report file."
            fi
        done
    done
}

test_negative_no_source() {
    rm -rf "$SOURCE_DIR"
    bash backup.bash
    assert_exit_code 1
    mkdir "$SOURCE_DIR"
}

test_negative_cannot_cp() {
    for file_name in "${FILES[@]}"; do
        for dir_name in "${DIRS[@]}"; do
            chmod 000 "$SOURCE_DIR/$dir_name/$file_name"
        done
    done
    bash backup.bash
    assert_exit_code 1
    chmod -R 744 "$SOURCE_DIR"
}

test_negative_cannot_access_home() {
    chmod 400 ~
    bash backup.bash
    assert_exit_code 1
    chmod 744 ~
}

TESTS=("test_positive_new_backup" "test_positive_update_backup_only_new_files" "test_positive_update_backup_update_files"
    "test_negative_no_source" "test_negative_cannot_cp" "test_negative_cannot_access_home")
for test_func in "${TESTS[@]}"; do
    echo -e "\e[32m\nTests: '$test_func' started.\n\e[0m"
    prepare
    $test_func
    echo -e "\e[32m\n'$test_func' tests done.\n\e[0m"
done