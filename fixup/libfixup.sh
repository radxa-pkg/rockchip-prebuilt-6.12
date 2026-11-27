#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

extract() {
    local tar_file="$1" target="$2"
    tar --extract -f "$tar_file" "./$target"
}

replace() {
    local tar_file="$1" target="$2"
    tar --delete -f "$tar_file" "./$target" # avoid duplicate members
    tar --append -f "$tar_file" "./$target" --owner=root --group=root
    rm "./$target"
}

fixup_loop() {
    while (( $# > 0))
    do
        local file_path file_name dir_path

        file_path="$1"
        file_name="$(basename "$file_path")"
        dir_path="$(dirname "$file_path")"
        shift

        pushd "$dir_path"

            ar x "$file_name"
            local ext=xz compressor=(xz)
            if [[ -f control.tar.zst ]]; then
                ext=zst
                compressor=(zstd --rm)
            fi
            "${compressor[@]}" -d -T0 "control.tar.$ext" "data.tar.$ext" # because tar --append does not work with compression
            extract control.tar control

            fixup_callback "$file_name"

            replace control.tar control
            "${compressor[@]}" -T0 control.tar data.tar
            ar r "$file_name" debian-binary "control.tar.$ext" "data.tar.$ext"
            rm debian-binary "control.tar.$ext" "data.tar.$ext"

        popd
    done
}
