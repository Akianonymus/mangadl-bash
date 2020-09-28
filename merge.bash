#!/usr/bin/env bash

set -e

./format.bash

{
    mkdir -p release/{standalone,split}

    # minified install script
    {
        sed -n 1p install.bash
        shfmt -mn -ln bash install.bash
    } >| "release/install"

    # standlone script
    {
        sed -n 1p mangadl.bash
        printf "%s\n" "SELF_SOURCE=\"true\""
        for file in utils/*scraper.bash; do
            : "${file#*utils\/}" && source="${_%-scraper.bash}"
            ALL_SOURCES+="\"${source}\" "
        done
        printf "%s" "ALL_SOURCES=(${ALL_SOURCES})" && printf "\n"
        {
            sed 1d utils/common-utils.bash && sed 1d utils/scraper-utils.bash
            for file in utils/*scraper.bash; do
                ! grep -q "# PLACEHOLDER" "${file}" && sed 1d "${file}"
            done
            sed 1d mangadl.bash
            # minify the standalone script using shfmt
        } | shfmt -ln bash -mn
    } >| "release/standalone/mangadl"

    # split minified utils and main script
    for i in mangadl.bash utils/*.bash; do
        {
            sed -n 1p "${i}"
            shfmt -mn "${i}"
        } >| "release/split/${i##*\/}"
    done

    chmod -R +x "release/"*
} &&
    printf "%s\n" "Merged and minified successfully."
