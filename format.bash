#!/usr/bin/env bash

if ! command -v shfmt 2>| /dev/null 1>&2; then
    printf 'Install shfmt to format script\n\n'
    printf 'Check https://github.com/mvdan/sh/releases\n'
    exit 1
fi

CURRENT_DIR="$(pwd)"
TEMPFILE="${CURRENT_DIR}/$(printf "%(%s)T\\n" "-1")"

trap 'rm -f "${TEMPFILE}".failedlog "${TEMPFILE}".passedlog' INT TERM EXIT

for i in *.bash utils/*.bash; do
    if ! shfmt -w "${i}"; then
        printf "%s\n\n" "${i}: ERROR" >> "${TEMPFILE}".failedlog
    else
        printf "%s\n" "${i}: SUCCESS" >> "${TEMPFILE}".passedlog
    fi
done

if [[ -f "${TEMPFILE}.failedlog" ]]; then
    printf '\nError: Cannot format some files.\n\n'
    printf "%s\n\n" "$(< "${TEMPFILE}".failedlog)"
    printf "%s\n\n" "$(< "${TEMPFILE}".passedlog)"
    exit 1
else
    printf 'All files formatted successfully.\n\n'
    printf "%s\n\n" "$(< "${TEMPFILE}".passedlog)"
    exit 0
fi
