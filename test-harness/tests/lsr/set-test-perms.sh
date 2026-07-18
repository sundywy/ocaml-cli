#!/usr/bin/env bash

set -u
DIR=${1:-$PWD}

if [[ $DIR == "-h" ]] || [[ $DIR == "--help" ]]; then
    printf "Usage: %s DIR\n" $(basename "$0")
    exit 0
fi

chmod 755 ${DIR}/tests/lsr/inputs/dir
chmod 600 ${DIR}/tests/lsr/inputs/fox.txt
chmod 644 ${DIR}/tests/lsr/inputs/.hidden ${DIR}/tests/lsr/inputs/empty.txt \
    ${DIR}/tests/lsr/inputs/bustle.txt ${DIR}/tests/lsr/inputs/dir/.gitkeep \
    ${DIR}/tests/lsr/inputs/dir/spiders.txt

echo "Done, fixed files in \"$DIR\"."
