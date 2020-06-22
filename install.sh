#!/usr/bin/env bash
# Install, Update or Uninstall mangadl-bash

_usage() {
    printf "
The script can be used to install mangadl-bash script in your system.\n
Usage: %s [options.. ]\n
All flags are optional.\n
Options:\n
  -i | --interactive - Install script interactively, will ask for all the varibles one by one.\nNote: This will disregard all arguments given with below flags.\n
  -p | --path <dir_name> - Custom path where you want to install script.\nDefault Path: %s/.mangadl-bash \n
  -c | --cmd <command_name> - Custom command name, after installation script will be available as the input argument.
      Default command: mangadl
  -r | --repo <Username/reponame> - Upload script from your custom repo,e.g --repo Akianonymus/mangadl-bash, make sure your repo file structure is same as official repo.\n
  -B | --branch <branch_name> - Specify branch name for the github repo, applies to custom and default repo both.\n
  -s | --shell-rc <shell_file> - Specify custom rc file, where PATH is appended, by default script detects .zshrc and .bashrc.\n
  -U | --uninstall - Uninstall the script and remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n" "${0##*/}" "${HOME}" "${HOME}"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Alternative to basename command
# Globals: None
# Arguments: 1
#   ${1} = anything
# Result: Read description.
###################################################
_basename() {
    printf "%s\n" "${1##*/}"
}

###################################################
# Check for bash version >= 4.x
# Globals: 1 Variable
#   BASH_VERSINFO
# Required Arguments: None
# Result: If
#   SUCEESS: Status 0
#   ERROR: print message and exit 1
###################################################
_check_bash_version() {
    { ! [[ ${BASH_VERSINFO:-0} -ge 4 ]] && printf "Bash version lower than 4.x not supported.\n" && exit 1; } || :
}

###################################################
# Check if debug is enabled and enable command trace
# Globals: 2 variables, 1 function
#   Varibles - DEBUG, QUIET
#   Function - _is_terminal
# Arguments: None
# Result: If DEBUG
#   Present - Enable command trace and change print functions to avoid spamming.
#   Absent  - Disable command trace
#             Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    _print_center_quiet() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
    if [[ -n ${DEBUG} ]]; then
        set -x
        _print_center() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _newline() { :; }
    else
        set +x
        if [[ -z ${QUIET} ]]; then
            if _is_terminal; then
                # This refreshes the interactive shell so we can use the ${COLUMNS} variable in the _print_center function.
                shopt -s checkwinsize && (: && :)
                if [[ ${COLUMNS} -lt 40 ]]; then
                    _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                else
                    trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
                fi
            else
                _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _newline() { :; }
        fi
    fi
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Globals: 2 functions
#   _print_center, _clear_line
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    _print_center "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com; then
        _clear_line 1
        printf "Error: Internet connection not available.\n"
        exit 1
    fi
    _clear_line 1
}

###################################################
# Move cursor to nth no. of line and clear it to the begining.
# Globals: None
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_clear_line() {
    printf "\033[%sA\033[2K" "${1}"
}

###################################################
# Detect profile rc file for zsh and bash.
# Detects for login shell of the user.
# Globals: 2 Variables
#   HOME, SHELL
# Arguments: None
# Result: On
#   Success - print profile file
#   Error   - print error message and exit 1
###################################################
_detect_profile() {
    declare CURRENT_SHELL="${SHELL##*/}"
    case "${CURRENT_SHELL}" in
        'bash') DETECTED_PROFILE="${HOME}/.bashrc" ;;
        'zsh') DETECTED_PROFILE="${HOME}/.zshrc" ;;
        *) if [[ -f "${HOME}/.profile" ]]; then
            DETECTED_PROFILE="${HOME}/.profile"
        else
            printf "No compaitable shell file\n" && exit 1
        fi ;;
    esac
    printf "%s\n" "${DETECTED_PROFILE}"
}

###################################################
# Alternative to dirname command
# Globals: None
# Arguments: 1
#   ${1} = path of file or folder
# Result: read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#get-the-directory-name-of-a-file-path
###################################################
_dirname() {
    declare tmp=${1:-.}

    [[ ${tmp} != *[!/]* ]] && { printf '/\n' && return; }
    tmp="${tmp%%"${tmp##*[!/]}"}"

    [[ ${tmp} != */* ]] && { printf '.\n' && return; }
    tmp=${tmp%/*} && tmp="${tmp%%"${tmp##*[!/]}"}"

    printf '%s\n' "${tmp:-/}"
}

###################################################
# Print full path of a file/folder
# Globals: 1 variable
#   PWD
# Arguments: 1
#   ${1} = name of file/folder
# Result: print full path
###################################################
_full_path() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare input="${1}"
    if [[ -f ${input} ]]; then
        printf "%s/%s\n" "$(cd "$(_dirname "${input}")" &> /dev/null && pwd)" "${input##*/}"
    elif [[ -d ${input} ]]; then
        printf "%s\n" "$(cd "${input}" &> /dev/null && pwd)"
    fi
}

###################################################
# Fetch latest commit sha of release or branch
# Uses github rest api v3
# Globals: None
# Arguments: 3
#   ${1} = "branch" or "release"
#   ${2} = branch name or release name
#   ${3} = repo name e.g Akianonymus/mangadl-bash
# Result: print fetched sha
###################################################
_get_latest_sha() {
    declare LATEST_SHA
    case "${1:-${TYPE}}" in
        branch)
            LATEST_SHA="$(curl --compressed -s https://api.github.com/repos/"${3:-${REPO}}"/commits/"${2:-${TYPE_VALUE}}" | _json_value sha)"
            ;;
        release)
            LATEST_SHA="$(curl --compressed -s https://api.github.com/repos/"${3:-${REPO}}"/releases/"${2:-${TYPE_VALUE}}" | _json_value tag_name)"
            ;;
    esac
    printf "%s\n" "${LATEST_SHA}"
}

###################################################
# Check if script running in a terminal
# Globals: 1 variable
#   TERM
# Arguments: None
# Result: return 1 or 0
###################################################
_is_terminal() {
    [[ -t 1 || -z ${TERM} ]] && return 0 || return 1
}

###################################################
# Method to extract specified field data from json
# Globals: None
# Arguments: 2
#   ${1} - value of field to fetch from json
#   ${2} - Optional, no of lines to parse
#   ${3} - Optional, nth number of value from extracted values, default it 1.
# Input: file | here string | pipe
#   _json_value "Arguments" < file
#   _json_value "Arguments <<< "${varibale}"
#   echo something | _json_value "Arguments"
# Result: print extracted value
###################################################
_json_value() {
    declare LC_ALL=C num
    { [[ ${2} =~ ^([0-9]+)+$ ]] && no_of_lines="${2}"; } || :
    { [[ ${3} =~ ^([0-9]+)+$ ]] && num="${3}"; } || { [[ ${3} != all ]] && num=1; }
    grep -o "\"${1}\"\:.*" ${no_of_lines+-m ${no_of_lines}} | sed -e "s/.*\"""${1}""\"://" -e 's/[",]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/\"//" -e "s/ //" -n -e "${num}"p
}

###################################################
# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
# Globals: 1 variable
#   COLUMNS
# Arguments: 4
#   If ${1} = normal
#      ${2} = text to print
#      ${3} = symbol
#   If ${1} = justify
#      If remaining arguments = 2
#         ${2} = text to print
#         ${3} = symbol
#      If remaining arguments = 3
#         ${2}, ${3} = text to print
#         ${4} = symbol
# Result: read description
# Reference:
#   https://gist.github.com/TrinityCoder/911059c83e5f7a351b785921cf7ecda
###################################################
_print_center() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare -i TERM_COLS="${COLUMNS}"
    declare type="${1}" filler
    case "${type}" in
        normal)
            declare out="${2}" && symbol="${3}"
            ;;
        justify)
            if [[ $# = 3 ]]; then
                declare input1="${2}" symbol="${3}" TO_PRINT out
                TO_PRINT="$((TERM_COLS - 5))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && out="[ ${input1:0:TO_PRINT}..]"; } || { out="[ ${input1} ]"; }
            else
                declare input1="${2}" input2="${3}" symbol="${4}" TO_PRINT temp out
                TO_PRINT="$((TERM_COLS * 40 / 100))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && temp+=" ${input1:0:TO_PRINT}.."; } || { temp+=" ${input1}"; }
                TO_PRINT="$((TERM_COLS * 55 / 100))"
                { [[ ${#input2} -gt ${TO_PRINT} ]] && temp+="${input2:0:TO_PRINT}.. "; } || { temp+="${input2} "; }
                out="[${temp}]"
            fi
            ;;
        *) return 1 ;;
    esac

    declare -i str_len=${#out}
    [[ $str_len -ge $(((TERM_COLS - 1))) ]] && {
        printf "%s\n" "${out}" && return 0
    }

    declare -i filler_len="$(((TERM_COLS - str_len) / 2))"
    [[ $# -ge 2 ]] && ch="${symbol:0:1}" || ch=" "
    for ((i = 0; i < filler_len; i++)); do
        filler="${filler}${ch}"
    done

    printf "%s%s%s" "${filler}" "${out}" "${filler}"
    [[ $(((TERM_COLS - str_len) % 2)) -ne 0 ]] && printf "%s" "${ch}"
    printf "\n"

    return 0
}

###################################################
# Remove duplicates, maintain the order as original.
# Globals: None
# Arguments: 1
#   ${@} = Anything
# Result: read description
# Reference:
#   https://stackoverflow.com/a/37962595
###################################################
_remove_array_duplicates() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare -A Aseen
    Aunique=()
    for i in "$@"; do
        { [[ -z ${i} || ${Aseen[${i}]} ]]; } && continue
        Aunique+=("${i}") && Aseen[${i}]=x
    done
    printf '%s\n' "${Aunique[@]}"
}

###################################################
# Alternative to tail -n command
# Globals: None
# Arguments: 1  or pipe
#   ${1} = file, _tail 1 < file
#          variable, _tail 1 <<< variable
#   pipe = echo something | _tail 1
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible
###################################################
_tail() {
    mapfile -tn 0 line
    printf '%s\n' "${line[@]: -$1}"
}

###################################################
# Alternative to timeout command
# Globals: None
# Arguments: 1 and rest
#   ${1} = amount of time to sleep
#   rest = command to execute
# Result: Return 0 or 1
# Reference:
#   https://stackoverflow.com/a/11056286
###################################################
_timeout() {
    declare -i sleep="${1}" && shift
    declare -i pid watcher
    {
        { "${@}"; } &
        pid="${!}"
        { read -t "${sleep:-10}" && kill -HUP "${pid}"; } &
        watcher="${!}"
        if wait "${pid}" 2> /dev/null; then
            kill -9 "${watcher}"
            return 0
        else
            return 1
        fi
    } &> /dev/null
}

###################################################
# Config updater
# Incase of old value, update, for new value add.
# Globals: 1 function
#   _remove_array_duplicates
# Arguments: 3
#   ${1} = value name
#   ${2} = value
#   ${3} = config path
# Result: read description
###################################################
_update_config() {
    [[ $# -lt 3 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1
    declare VALUE_NAME="${1}" VALUE="${2}" CONFIG_PATH="${3}" FINAL=()
    printf "" >> "${CONFIG_PATH}" # If config file doesn't exist.
    mapfile -t VALUES < "${CONFIG_PATH}" && VALUES+=("${VALUE_NAME}=\"${VALUE}\"")
    for i in "${VALUES[@]}"; do
        [[ ${i} =~ ${VALUE_NAME}\= ]] && FINAL+=("${VALUE_NAME}=\"${VALUE}\"") || FINAL+=("${i}")
    done
    _remove_array_duplicates "${FINAL[@]}" >| "${CONFIG_PATH}"
}

###################################################
# Initialize default variables
# Globals: 1 variable, 1 function
#   Variable - HOME
#   Function - _detect_profile
# Arguments: None
# Result: read description
###################################################
_variables() {
    UTILS_FOLDER="${UTILS_FOLDER:-./utils}"
    REPO="Akianonymus/mangadl-bash"
    COMMAND_NAME="mangadl"
    INFO_PATH="${HOME}/.mangadl-bash"
    INSTALL_PATH="${HOME}/.mangadl-bash/bin"
    TYPE="branch"
    TYPE_VALUE="master"
    SHELL_RC="$(_detect_profile)"
    # shellcheck source=/dev/null
    if [[ -r ${INFO_PATH}/mangadl-bash.info ]]; then
        source "${INFO_PATH}"/mangadl-bash.info
    fi
    __VALUES_ARRAY=(REPO COMMAND_NAME INSTALL_PATH TYPE TYPE_VALUE SHELL_RC)
}

###################################################
# Download files, script and utils, write latest sha to downloaded file for comparison
# Arguments: None
# Result: read description
###################################################
_download_files() {
    cd "${INSTALL_PATH}" &> /dev/null
    for url in "${UTILS_URLS[@]}"; do
        file="$(_basename "${url}")"
        if [[ $(_tail 1 < "${file}") = "#${LATEST_CURRENT_SHA}" ]]; then
            continue
        fi
        if ! curl -# --compressed -L "${url}" -o "${file}"; then
            return 1
        fi
        printf "\n#%s\n" "${LATEST_CURRENT_SHA}" >> "${file}"
        _clear_line 1
    done
    file="${COMMAND_NAME}"
    if [[ $(_tail 1 < "${file}") = "#${LATEST_CURRENT_SHA}" ]]; then
        return
    fi
    if ! curl --compressed -L -# "https://raw.githubusercontent.com/${REPO}/${LATEST_CURRENT_SHA}/mangadl.sh" -o "${COMMAND_NAME}"; then
        return 1
    fi
    printf "\n#%s\n" "${LATEST_CURRENT_SHA}" >> "${file}"
    _clear_line 1
    cd - &> /dev/null
}

###################################################
# Start a interactive session, asks for all the varibles.
# Globals: 1 variable, 1 function
#   Variable - __VALUES_ARRAY ( array )
#   Function - _clear_line
# Arguments: None
# Result: read description
#   If tty absent, then exit
###################################################
_start_interactive() {
    _print_center "justify" "Interactive Mode" "="
    _print_center "justify" "Press return for default values.." "-"
    for i in "${__VALUES_ARRAY[@]}"; do
        j="${!i}" && k="${i}"
        read -r -p "${i} [ Default: ${j} ]: " "${i?}"
        if [[ -z ${!i} ]]; then
            read -r "${k?}" <<< "${j}"
        fi
    done
    for _ in "${__VALUES_ARRAY[@]}"; do _clear_line 1; done
    for _ in {1..3}; do _clear_line 1; done
    for i in "${__VALUES_ARRAY[@]}"; do
        if [[ -n ${i} ]]; then
            printf "%s\n" "${i}: ${!i}"
        fi
    done
}

###################################################
# Install the script
# Globals: 10 variables, 6 functions
#   Variables - INSTALL_PATH, INFO_PATH, UTILS_FILE, COMMAND_NAME, SYNC_COMMAND_NAME, SHELL_RC,
#               TYPE, TYPE_VALUE, REPO, __VALUES_ARRAY ( array )
#   Functions - _print_center, _newline, _clear_line
#               _get_latest_sha, _update_config
# Arguments: None
# Result: read description
#   If cannot download, then print message and exit
###################################################
_install() {
    mkdir -p "${INSTALL_PATH}"
    _print_center "justify" 'Installing mangadl-bash..' "-"
    _print_center "justify" "Fetching latest sha.." "-"
    LATEST_CURRENT_SHA="$(_get_latest_sha "${TYPE}" "${TYPE_VALUE}" "${REPO}")"
    _clear_line 1
    _print_center "justify" "Latest sha fetched." "=" && _print_center "justify" "Downloading scripts.." "-"
    mapfile -t UTILS_URLS <<< "$(curl --compressed -# https://api.github.com/repos/"${REPO}"/contents/utils?ref="${TYPE_VALUE}" | _json_value download_url all all)"
    _clear_line 1
    if _download_files; then
        if ! grep "UTILS_FOLDER=\"${INSTALL_PATH}\"" "${INSTALL_PATH}/${COMMAND_NAME}" &> /dev/null; then
            sed -i "2a UTILS_FOLDER=\"${INSTALL_PATH}\"" "${INSTALL_PATH}/${COMMAND_NAME}"
        fi
        chmod +x "${INSTALL_PATH}"/*
        for i in "${__VALUES_ARRAY[@]}"; do
            _update_config "${i}" "${!i}" "${INFO_PATH}"/mangadl-bash.info
        done
        _update_config LATEST_INSTALLED_SHA "${LATEST_CURRENT_SHA}" "${INFO_PATH}"/mangadl-bash.info
        _update_config PATH "${INSTALL_PATH}:${PATH}" "${INFO_PATH}"/mangadl-bash.binpath
        if ! grep "source ${INFO_PATH}/mangadl-bash.binpath" "${SHELL_RC}" &> /dev/null; then
            printf "\nsource %s/mangadl-bash.binpath" "${INFO_PATH}" >> "${SHELL_RC}"
        fi
        for _ in {1..3}; do _clear_line 1; done
        _print_center "justify" "Installed Successfully" "="
        _print_center "normal" "[ Command name: ${COMMAND_NAME} ]" "="
        _print_center "justify" "To use the command, do" "-"
        _newline "\n" && _print_center "normal" "source ${SHELL_RC}" " "
        _print_center "normal" "or" " "
        _print_center "normal" "restart your terminal." " "
        _newline "\n" && _print_center "normal" "To update the script in future, just run ${COMMAND_NAME} --update." " "
    else
        _clear_line 1
        _print_center "justify" "Cannot download the script." "="
        exit 1
    fi
}

###################################################
# Update the script
# Globals: 10 variables, 6 functions
#   Variables - INSTALL_PATH, INFO_PATH, UTILS_FILE, COMMAND_NAME, SHELL_RC,
#               TYPE, TYPE_VALUE, REPO, __VALUES_ARRAY ( array )
#   Functions - _print_center, _newline, _clear_line
#               _get_latest_sha _update_config
# Arguments: None
# Result: read description
#   If cannot download, then print message and exit
###################################################
_update() {
    _print_center "justify" "Fetching latest version info.." "-"
    LATEST_CURRENT_SHA="$(_get_latest_sha "${TYPE}" "${TYPE_VALUE}" "${REPO}")"
    if [[ -z "${LATEST_CURRENT_SHA}" ]]; then
        _print_center "justify" "Cannot fetch remote latest version." "="
        exit 1
    fi
    _clear_line 1
    if [[ ${LATEST_CURRENT_SHA} = "${LATEST_INSTALLED_SHA}" ]]; then
        _print_center "justify" "Latest mangadl-bash already installed." "="
    else
        _print_center "justify" "Updating.." "-"
        mapfile -t UTILS_URLS <<< "$(curl --compressed -s https://api.github.com/repos/"${REPO}"/contents/utils?ref="${TYPE_VALUE}" | _json_value download_url all all)"
        if _download_files; then
            if ! grep "UTILS_FOLDER=\"${INSTALL_PATH}\"" "${INSTALL_PATH}/${COMMAND_NAME}" &> /dev/null; then
                sed -i "2a UTILS_FOLDER=\"${INSTALL_PATH}\"" "${INSTALL_PATH}/${COMMAND_NAME}"
            fi
            chmod +x "${INSTALL_PATH}"/*
            for i in "${__VALUES_ARRAY[@]}"; do
                _update_config "${i}" "${!i}" "${INFO_PATH}"/mangadl-bash.info
            done
            _update_config LATEST_INSTALLED_SHA "${LATEST_CURRENT_SHA}" "${INFO_PATH}"/mangadl-bash.info
            _update_config PATH "${INSTALL_PATH}:${PATH}" "${INFO_PATH}"/mangadl-bash.binpath
            if ! grep "source ${INFO_PATH}/mangadl-bash.binpath" "${SHELL_RC}" &> /dev/null; then
                printf "\nsource %s/mangadl-bash.binpath" "${INFO_PATH}" >> "${SHELL_RC}"
            fi
            _clear_line 1
            for i in "${__VALUES_ARRAY[@]}"; do
                _update_config "${i}" "${!i}" "${INFO_PATH}"/mangadl-bash.info
            done
            _print_center "justify" 'Successfully Updated.' "="
        else
            _clear_line 1
            _print_center "justify" "Cannot download the script." "="
            exit 1
        fi
    fi
}

###################################################
# Uninstall the script
# Globals: 5 variables, 2 functions
#   Variables - INSTALL_PATH, INFO_PATH, UTILS_FILE, COMMAND_NAME, SHELL_RC
#   Functions - _print_center, _clear_line
# Arguments: None
# Result: read description
#   If cannot edit the SHELL_RC, then print message and exit
###################################################
_uninstall() {
    _print_center "justify" "Uninstalling.." "-"
    __bak="source ${INFO_PATH}/mangadl-bash.binpath"
    if sed -i "s|${__bak}||g" "${SHELL_RC}"; then
        rm -f "${INSTALL_PATH}"/*sh "${INSTALL_PATH}"/"${COMMAND_NAME}"
        rm -f "${INFO_PATH}"/{mangadl-bash.info,mangadl-bash.binpath,mangadl-bash.configpath}
        _clear_line 1
        _print_center "justify" "Uninstall complete." "="
    else
        _print_center "justify" 'Error: Uninstall failed.' "="
    fi
}

###################################################
# Process all arguments given to the script
# Globals: 1 variable, 2 functions
#   Variable - SHELL_RC
#   Functions - _is_terminal, _full_path
# Arguments: Many
#   ${@} = Flags with arguments
# Result: read description
#   If no shell rc file found, then print message and exit
###################################################
_setup_arguments() {
    [[ $# = 0 ]] && printf "%s: Missing arguments\n" "${FUNCNAME[0]}" && return 1

    _check_longoptions() {
        { [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1; } || :
    }

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help)
                _usage
                ;;
            -i | --interactive)
                if _is_terminal; then
                    INTERACTIVE="true"
                    return 0
                else
                    printf "Cannot start interactive mode in an non tty environment\n"
                    exit 1
                fi
                ;;
            -p | --path)
                _check_longoptions "${1}" "${2}"
                INSTALL_PATH="${2}" && shift
                ;;
            -r | --repo)
                _check_longoptions "${1}" "${2}"
                REPO="${2}" && shift
                ;;
            -c | --cmd)
                _check_longoptions "${1}" "${2}"
                COMMAND_NAME="${2}" && shift
                ;;
            -B | --branch)
                _check_longoptions "${1}" "${2}"
                TYPE_VALUE="${2}" && shift
                TYPE=branch
                ;;
            -s | --shell-rc)
                _check_longoptions "${1}" "${2}"
                SHELL_RC="${2}" && shift
                ;;
            -U | --uninstall)
                UNINSTALL="true"
                ;;
            -D | --debug)
                DEBUG=true
                export DEBUG
                ;;
            '')
                _short_help
                ;;
            *)
                printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1
                ;;
        esac
        shift
    done

    if [[ -z ${SHELL_RC} ]]; then
        printf "No default shell file found, use -s/--shell-rc to use custom rc file\n"
        exit 1
    else
        if ! [[ -f ${SHELL_RC} ]]; then
            printf "Given shell file ( %s ) does not exist.\n" "${SHELL_RC}"
            exit 1
        fi
    fi
}

main() {
    _variables
    if [[ $* ]]; then
        _setup_arguments "${@}"
    fi

    _check_debug && _check_bash_version

    if [[ -n ${INTERACTIVE} ]]; then
        _start_interactive
    fi

    if [[ -n ${UNINSTALL} ]]; then
        if type -a "${COMMAND_NAME}" &> /dev/null; then
            _uninstall
        else
            _print_center "justify" "mangadl-bash is not installed." "="
            exit 1
        fi
    else
        _check_internet
        if type -a "${COMMAND_NAME}" &> /dev/null; then
            _update
        else
            _install
        fi
    fi
}

main "${@}"
