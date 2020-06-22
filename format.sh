#!/usr/bin/env bash

if ! type -p shfmt > /dev/null 2>&1; then
    printf 'Install shfmt to format script\n\n'
    printf 'You can install it by bash <(curl -L -s https://gist.github.com/Akianonymus/56e80cc1aa469c5b74d41273e202cadd/raw/24bdfd9fd0ceca53b923fe4b694c03be0b208d2a/install-shfmt.sh), or\n'
    printf 'Check https://github.com/mvdan/sh/releases\n'
    exit 1
fi

for i in *sh */*sh; do
    if ! shfmt -ci -sr -i 4 -w "$i"; then
        printf "%s\n" "$i: Failed" >> failedlog
    else
        printf "%s\n" "$i: Passed" >> log
    fi
done

if [[ -f failedlog ]]; then
    printf '\nSome checks have failed.\n\n'
    cat failedlog && printf '\n'
    cat log && rm -f failedlog log
    exit 1
else
    printf 'All checks have passed.\n\n'
    cat log && rm -f log
    exit 0
fi
