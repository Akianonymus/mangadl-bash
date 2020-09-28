#!/usr/bin/env bash
# Install, Update or Uninstall mangadl-bash
# shellcheck source=/dev/null

_usage() {
    printf "%s\n" "
The script can be used to install mangadl-bash script in your system.\n
Usage: ${0##*/} [options.. ]\n
All flags are optional.\n
Options:\n
  -p | --path <dir_name> - Custom path where you want to install script.\nDefault Path: ${HOME}/.mangadl-bash \n
  -c | --cmd <command_name> - Custom command name, after installation script will be available as the input argument.
      Default command: mangadl
  -r | --repo <Username/reponame> - Upload script from your custom repo,e.g --repo Akianonymus/mangadl-bash, make sure your repo file structure is same as official repo.\n
  -b | --branch <branch_name> - Specify branch name for the github repo, applies to custom and default repo both.\n
  -s | --shell-rc <shell_file> - Specify custom rc file, where PATH is appended, by default script detects .zshrc and .bashrc.\n
  -t | --time 'no of days' - Specify custom auto update time ( given input will taken as number of days ) after which script will try to automatically update itself.\n
      Default: 3 ( 3 days )\n
  --skip-internet-check - Like the flag says.\n
  -q | --quiet - Only show critical error/sucess logs.\n
  -U | --uninstall - Uninstall the script and remove related files.\n
  -D | --debug - Display script command trace.\n
  -h | --help - Display usage instructions.\n"
    exit 0
}

_short_help() {
    printf "No valid arguments provided, use -h/--help flag to see usage.\n"
    exit 0
}

###################################################
# Check if debug is enabled and enable command trace
# Arguments: None
# Result: If DEBUG
#   Present - Enable command trace and change print functions to avoid spamming.
#   Absent  - Disable command trace
#             Check QUIET, then check terminal size and enable print functions accordingly.
###################################################
_check_debug() {
    _print_center_quiet() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
    if [[ -n ${DEBUG} ]]; then
        set -x && PS4='-> '
        _print_center() { { [[ $# = 3 ]] && printf "%s\n" "${2}"; } || { printf "%s%s\n" "${2}" "${3}"; }; }
        _clear_line() { :; } && _newline() { :; }
    else
        if [[ -z ${QUIET} ]]; then
            if _support_ansi_escapes; then
                # This refreshes the interactive shell so we can use the ${COLUMNS} variable in the _print_center function.
                shopt -s checkwinsize && (: && :)
                if [[ ${COLUMNS} -lt 45 ]]; then
                    _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                else
                    trap 'shopt -s checkwinsize; (:;:)' SIGWINCH
                fi
                CURL_PROGRESS="-#" EXTRA_LOG="_print_center" CURL_PROGRESS_EXTRA="-#"
                export CURL_PROGRESS EXTRA_LOG CURL_PROGRESS_EXTRA
            else
                _print_center() { { [[ $# = 3 ]] && printf "%s\n" "[ ${2} ]"; } || { printf "%s\n" "[ ${2}${3} ]"; }; }
                _clear_line() { :; }
            fi
            _newline() { printf "%b" "${1}"; }
        else
            _print_center() { :; } && _clear_line() { :; } && _newline() { :; }
        fi
        set +x
    fi
}

###################################################
# Check if the required executables are installed
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_dependencies() {
    declare -a error_list

    for program in curl wget xargs mkdir rm grep sed sleep; do
        command -v "${program}" 2>| /dev/null 1>&2 || error_list+=("${program}")
    done

    [ -n "${error_list[*]}" ] && [ -z "${UNINSTALL}" ] && {
        printf "Error: "
        printf "%b, " "${error_list[*]}"
        printf "%b" "not found, install before proceeding.\n"
        exit 1
    }
    return 0
}

###################################################
# Check internet connection.
# Probably the fastest way, takes about 1 - 2 KB of data, don't check for more than 10 secs.
# Arguments: None
# Result: On
#   Success - Nothing
#   Error   - print message and exit 1
###################################################
_check_internet() {
    "${EXTRA_LOG:-:}" "justify" "Checking Internet Connection.." "-"
    if ! _timeout 10 curl -Is google.com; then
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Error: Internet connection" " not available." "="
        exit 1
    fi
    _clear_line 1
}

###################################################
# Move cursor to nth no. of line and clear it to the begining.
# Arguments: 1
#   ${1} = Positive integer ( line number )
# Result: Read description
###################################################
_clear_line() {
    printf "\033[%sA\033[2K" "${1}"
}

###################################################
# Alternative to wc -l command
# Arguments: 1  or pipe
#   ${1} = file, _count < file
#          variable, _count <<< variable
#   pipe = echo something | _count
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible#get-the-number-of-lines-in-a-file
###################################################
_count() {
    mapfile -tn 0 lines
    printf '%s\n' "${#lines[@]}"
}

###################################################
# Detect profile rc file for zsh and bash.
# Detects for login shell of the user.
# Arguments: None
# Result: On
#   Success - print profile file
#   Error   - print error message and exit 1
###################################################
_detect_profile() {
    CURRENT_SHELL="${SHELL##*/}"
    case "${CURRENT_SHELL}" in
        *bash*) DETECTED_PROFILE="${HOME}/.bashrc" ;;
        *zsh*) DETECTED_PROFILE="${HOME}/.zshrc" ;;
        *ksh*) DETECTED_PROFILE="${HOME}/.kshrc" ;;
        *) DETECTED_PROFILE="${HOME}/.profile" ;;
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
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
# Arguments: 3
#   ${1} = repo name
#   ${2} = sha sum or branch name or tag name
#   ${3} = path ( optional )
# Result: print fetched shas
###################################################
_get_files_and_commits() {
    declare repo="${1:-${REPO}}" type_value="${2:-${LATEST_CURRENT_SHA}}" path="${3:-}"
    declare html commits files

    # shellcheck disable=SC2086
    html="$(curl -s --compressed "https://github.com/${repo}/file-list/${type_value}/${path}")" ||
        { _print_center "normal" "Error: Cannot fetch" " update details" "=" 1>&2 && exit 1; }
    commits="$(printf "%s\n" "${html}" | grep -o "commit/.*\"" | sed -e 's/commit\///g' -e 's/\"//g' -e 's/>.*//g')"
    # shellcheck disable=SC2001
    files="$(printf "%s\n" "${html}" | grep -oE '(blob|tree)/'"${type_value}"'.*\"' | sed -e 's/\"//g' -e 's/>.*//g')"

    total_files="$(printf "%s\n" "${files}" | _count)"
    total_commits="$(printf "%s\n" "${commits}" | _count)"
    if [[ "$((total_files - 2))" -eq "${total_commits}" ]]; then
        files="$(printf "%s\n" "${files}" | sed 1,2d)"
    elif [[ "${total_files}" -gt "${total_commits}" ]]; then
        files="$(printf "%s\n" "${files}" | sed 1d)"
    fi

    while read -u 4 -r file && read -u 5 -r commit; do
        printf "%s\n" "${file##blob\/${type_value}\/}__.__${commit}"
    done 4<<< "${files}" 5<<< "${commits}" | grep -v tree || :

    return 0
}

###################################################
# Fetch latest commit sha of release or branch
# Do not use github rest api because rate limit error occurs
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
            LATEST_SHA="$(
                : "$(curl --compressed -s https://github.com/"${3:-${REPO}}"/commits/"${2:-${TYPE_VALUE}}".atom -r 0-2000)"
                : "$(printf "%s\n" "${_}" | grep -o "Commit\\/.*<" -m1 || :)" && : "${_##*\/}" && printf "%s\n" "${_%%<*}"
            )"
            ;;
        release)
            LATEST_SHA="$(
                : "$(curl -L --compressed -s https://github.com/"${3:-${REPO}}"/releases/"${2:-${TYPE_VALUE}}")"
                : "$(printf "%s\n" "${_}" | grep "=\"/""${3:-${REPO}}""/commit" -m1 || :)" && : "${_##*commit\/}" && printf "%s\n" "${_%%\"*}"
            )"
            ;;
    esac
    printf "%b" "${LATEST_SHA:+${LATEST_SHA}\n}"
}

###################################################
# Print a text to center interactively and fill the rest of the line with text specified.
# This function is fine-tuned to this script functionality, so may appear unusual.
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
        normal) declare out="${2}" && symbol="${3}" ;;
        justify)
            if [[ $# = 3 ]]; then
                declare input1="${2}" symbol="${3}" TO_PRINT out
                TO_PRINT="$((TERM_COLS - 5))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && out="[ ${input1:0:TO_PRINT}..]"; } || { out="[ ${input1} ]"; }
            else
                declare input1="${2}" input2="${3}" symbol="${4}" TO_PRINT temp out
                TO_PRINT="$((TERM_COLS * 47 / 100))"
                { [[ ${#input1} -gt ${TO_PRINT} ]] && temp+=" ${input1:0:TO_PRINT}.."; } || { temp+=" ${input1}"; }
                TO_PRINT="$((TERM_COLS * 46 / 100))"
                { [[ ${#input2} -gt ${TO_PRINT} ]] && temp+="${input2:0:TO_PRINT}.. "; } || { temp+="${input2} "; }
                out="[${temp}]"
            fi
            ;;
        *) return 1 ;;
    esac

    declare -i str_len=${#out}
    [[ $str_len -ge $((TERM_COLS - 1)) ]] && {
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
# Check if script terminal supports ansi escapes
# Arguments: None
# Result: return 1 or 0
###################################################
_support_ansi_escapes() {
    { [[ -t 2 && -n ${TERM} && ${TERM} =~ (xterm|rxvt|urxvt|linux|vt) ]] && return 0; } || return 1
}

###################################################
# Alternative to tail -n command
# Arguments: 1  or pipe
#   ${1} = file, _tail 1 < file
#          variable, _tail 1 <<< variable
#   pipe = echo something | _tail 1
# Result: Read description
# Reference:
#   https://github.com/dylanaraps/pure-bash-bible/blob/master/README.md#get-the-last-n-lines-of-a-file
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
# Result: Read description
# Reference:
#   https://stackoverflow.com/a/24416732
###################################################
_timeout() {
    declare timeout="${1:?Error: Specify Timeout}" && shift
    {
        "${@}" &
        child="${!}"
        trap -- "" TERM
        {
            sleep "${timeout}"
            kill -9 "${child}"
        } &
        wait "${child}"
    } 2>| /dev/null 1>&2
}

###################################################
# Initialize default variables
# Arguments: None
# Result: read description
###################################################
_variables() {
    REPO="Akianonymus/mangadl-bash"
    COMMAND_NAME="mangadl"
    INSTALL_PATH="${HOME}/.mangadl-bash"
    TYPE="branch"
    TYPE_VALUE="master"
    SHELL_RC="$(_detect_profile)"
    LAST_UPDATE_TIME="$(printf "%(%s)T\\n" "-1")" && export LAST_UPDATE_TIME
    GLOBAL_INSTALL="false"

    VALUES_LIST="REPO COMMAND_NAME INSTALL_PATH TYPE TYPE_VALUE SHELL_RC LAST_UPDATE_TIME AUTO_UPDATE_INTERVAL GLOBAL_INSTALL ALL_FILES"

    VALUES_REGEX="" && for i in VALUES_LIST ${VALUES_LIST}; do
        VALUES_REGEX="${VALUES_REGEX:+${VALUES_REGEX}|}^${i}=\".*\".* # added values"
    done

    return 0
}

###################################################
# Download scripts
###################################################
_download_file() {
    cd "${INSTALL_PATH}" 2>| /dev/null 1>&2 || exit 1

    [[ ${GLOBAL_INSTALL} = true ]] && remote_folder="standalone" || remote_folder="split"
    release="$(_get_files_and_commits "${REPO}" "${LATEST_CURRENT_SHA}" "release/${remote_folder}")"

    while read -u 4 -r line; do
        file="${line%%__.__*}" && file="${file//release\/${remote_folder}\//}" && sha="${line##*__.__}"
        case "${file}" in
            mangadl*) local_file="${COMMAND_NAME}" && export SCRIPT_SHA="${sha}" ;;
            *) local_file="${file}" ;;
        esac
        [[ -f ${local_file} ]] && {
            [[ $(_tail 1 < "${local_file}") = "#${sha}" ]] && continue
            chmod +w "${local_file}"
        }
        _print_center "justify" "${local_file}" "-"
        # shellcheck disable=SC2086
        ! curl -s --compressed "https://raw.githubusercontent.com/${REPO}/${sha}/${line%%__.__*}" -o "${local_file}" && return 1
        _clear_line 1
        printf "\n%s\n" "#${sha}" >> "${local_file}"
        [[ ${ALL_FILES} =~ ${local_file} ]] || ALL_FILES+="${local_file} "
    done 4<<< "${release}"

    cd - 2>| /dev/null 1>&2 || exit 1
    return 0
}

###################################################
# Inject installation values to mangadl script
###################################################
_inject_values() {
    declare shebang script_without_values_and_shebang
    shebang="$(sed -n 1p "${INSTALL_PATH}/${COMMAND_NAME}")"
    script_without_values_and_shebang="$(grep -vE "${VALUES_REGEX}|^LATEST_INSTALLED_SHA=\".*\".* # added values" "${INSTALL_PATH}/${COMMAND_NAME}" | sed 1d)"
    {
        printf "%s\n" "${shebang}"
        for i in VALUES_LIST ${VALUES_LIST}; do
            printf "%s\n" "${i}=\"${!i}\" # added values"
        done
        printf "%s\n" "LATEST_INSTALLED_SHA=\"${LATEST_CURRENT_SHA}\" # added values"
        printf "%s\n" "${script_without_values_and_shebang}"
    } 1>| "${INSTALL_PATH}/${COMMAND_NAME}"
}

###################################################
# Install/Update the upload and sync script
# Arguments: None
# Result: read description
#   If cannot download, then print message and exit
###################################################
_start() {
    job="${1:-install}"

    [[ "${job}" = install ]] && _print_center "justify" 'Installing mangadl-bash..' "-"

    _print_center "justify" "Fetching latest version info.." "-"
    LATEST_CURRENT_SHA="$(_get_latest_sha "${TYPE}" "${TYPE_VALUE}" "${REPO}")"
    [[ -z "${LATEST_CURRENT_SHA}" ]] && "${QUIET:-_print_center}" "justify" "Cannot fetch remote latest version." "=" && exit 1
    _clear_line 1

    [[ "${job}" = update ]] && {
        [[ "${LATEST_CURRENT_SHA}" = "${LATEST_INSTALLED_SHA}" ]] && "${QUIET:-_print_center}" "justify" "Latest mangadl-bash already installed." "=" && return 0
        _print_center "justify" "Updating.." "-"
    }

    _print_center "justify" "Downloading.." "-"
    if _download_file; then
        _inject_values || { "${QUIET:-_print_center}" "normal" "Cannot edit installed files" ", check if create a issue on github with proper log." "=" && exit 1; }

        for i in ${ALL_FILES}; do
            chmod "${GLOBAL_PERMS:-u+x+r-w}" "${INSTALL_PATH}/${i}"
        done

        [[ "${GLOBAL_INSTALL}" = false ]] && {
            _PATH="PATH=\"${INSTALL_PATH}:\${PATH}\""
            { grep -q "${_PATH}" "${SHELL_RC}" 2>| /dev/null || {
                (printf "\n%s\n" "${_PATH}" >> "${SHELL_RC}") 2>| /dev/null || {
                    shell_rc_write="error"
                    _shell_rc_err_msg() {
                        "${QUIET:-_print_center}" "normal" " Cannot edit SHELL RC file " "=" && printf "\n"
                        "${QUIET:-_print_center}" "normal" " ${SHELL_RC} " " " && printf "\n"
                        "${QUIET:-_print_center}" "normal" " Add below line to your shell rc manually " "-" && printf "\n"
                        "${QUIET:-_print_center}" "normal" "${_PATH}" " " && printf "\n"
                    }
                }
            }; } || :
        }

        for _ in 1 2; do _clear_line 1; done

        if [[ "${job}" = install ]]; then
            { [[ -n "${shell_rc_write}" ]] && _shell_rc_err_msg; } || {
                "${QUIET:-_print_center}" "justify" "Installed Successfully" "="
                "${QUIET:-_print_center}" "normal" "[ Command name: ${COMMAND_NAME} ]" "="
            }
            _print_center "justify" "To use the command, do" "-"
            _newline "\n" && _print_center "normal" ". ${SHELL_RC}" " "
            _print_center "normal" "or" " "
            _print_center "normal" "restart your terminal." " "
            _newline "\n" && _print_center "normal" "To update the script in future, just run ${COMMAND_NAME} -u/--update." " "
        else
            { [[ -n "${shell_rc_write}" ]] && _shell_rc_err_msg; } ||
                "${QUIET:-_print_center}" "justify" 'Successfully Updated.' "="
        fi
    else
        _clear_line 1
        "${QUIET:-_print_center}" "justify" "Cannot download the scripts." "="
        exit 1
    fi
    return 0
}

###################################################
# Uninstall the script
# Arguments: None
# Result: read description
#   If cannot edit the SHELL_RC, then print message and exit
###################################################
_uninstall() {
    _print_center "justify" "Uninstalling.." "-"

    _PATH="PATH=\"${INSTALL_PATH}:\${PATH}\""

    _error_message() {
        "${QUIET:-_print_center}" "justify" 'Error: Uninstall failed.' "="
        "${QUIET:-_print_center}" "normal" " Cannot edit SHELL RC file " "=" && printf "\n"
        "${QUIET:-_print_center}" "normal" " ${SHELL_RC} " " " && printf "\n"
        "${QUIET:-_print_center}" "normal" " Remove below line from your shell rc manually " "-" && printf "\n"
        "${QUIET:-_print_center}" "normal" " ${1}" " " && printf "\n"
        return 1
    }

    [[ ${GLOBAL_INSTALL} = false ]] && {
        { grep -q "${_PATH}" "${SHELL_RC}" 2>| /dev/null &&
            ! { [[ -w "${SHELL_RC}" ]] &&
                _new_rc="$(sed -e "s|${_PATH}||g" "${SHELL_RC}")" && printf "%s\n" "${_new_rc}" >| "${SHELL_RC}"; } &&
            _error_message "${_PATH}"; } || :
    }

    for file in ${ALL_FILES}; do
        chmod -f u+w "${INSTALL_PATH}/${file}"
        rm -f "${INSTALL_PATH:?}/${file}"
    done

    [[ "${GLOBAL_INSTALL}" = false && -z "$(find "${INSTALL_PATH}" -type f)" ]] && rm -rf "${INSTALL_PATH:?}"

    _clear_line 1
    _print_center "justify" "Uninstall complete." "="
    return 0
}

###################################################
# Process all arguments given to the script
# Arguments: Many
#   ${@} = Flags with arguments
# Result: read description
#   If no shell rc file found, then print message and exit
###################################################
_setup_arguments() {
    _check_longoptions() {
        [[ -z ${2} ]] &&
            printf '%s: %s: option requires an argument\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" &&
            exit 1
        return 0
    }

    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -h | --help) _usage ;;
            -p | --path)
                _check_longoptions "${1}" "${2}"
                _INSTALL_PATH="${2}" && shift
                ;;
            -r | --repo)
                _check_longoptions "${1}" "${2}"
                REPO="${2}" && shift
                ;;
            -c | --cmd)
                _check_longoptions "${1}" "${2}"
                COMMAND_NAME="${2}" && shift
                ;;
            -b | --branch)
                _check_longoptions "${1}" "${2}"
                TYPE_VALUE="${2}" && shift
                TYPE=branch
                ;;
            -s | --shell-rc)
                _check_longoptions "${1}" "${2}"
                SHELL_RC="${2}" && shift
                ;;
            -t | --time)
                _check_longoptions "${1}" "${2}"
                if [[ "${2}" -gt 0 ]] 2>| /dev/null; then
                    AUTO_UPDATE_INTERVAL="$((2 * 86400))" && shift
                else
                    printf "\nError: -t/--time value can only be a positive integer.\n"
                    exit 1
                fi
                ;;
            -q | --quiet) QUIET="_print_center_quiet" ;;
            --skip-internet-check) SKIP_INTERNET_CHECK=":" ;;
            -U | --uninstall) UNINSTALL="true" ;;
            -D | --debug) DEBUG="true" && export DEBUG ;;
            *) printf '%s: %s: Unknown option\nTry '"%s -h/--help"' for more information.\n' "${0##*/}" "${1}" "${0##*/}" && exit 1 ;;
        esac
        shift
    done

    # 86400 secs = 1 day
    AUTO_UPDATE_INTERVAL="${AUTO_UPDATE_INTERVAL:-259200}"

    [[ -z "${SHELL_RC}" ]] && printf "No default shell file found, use -s/--shell-rc to use custom rc file\n" && exit 1

    INSTALL_PATH="${_INSTALL_PATH:-${INSTALL_PATH}}"
    mkdir -p "${INSTALL_PATH}" 2> /dev/null || :
    INSTALL_PATH="$(cd "${INSTALL_PATH%\/*}" && pwd)/${INSTALL_PATH##*\/}" || exit 1
    { printf "%s\n" "${PATH}" | grep -q -e "${INSTALL_PATH}:" -e "${INSTALL_PATH}/:" && IN_PATH="true"; } || :

    # check if install path outside home dir and running as root
    [[ -n "${INSTALL_PATH##${HOME}*}" ]] && GLOBAL_PERMS="a+r+x-w" && GLOBAL_INSTALL="true" && ! [[ "$(id -u)" = 0 ]] &&
        printf "%s\n" "Error: Need root access to run the script for given install path ( ${INSTALL_PATH} )." && exit 1

    # global dir must be in executable path
    [[ "${GLOBAL_INSTALL}" = true ]] && [[ -z "${IN_PATH}" ]] &&
        printf "%s\n" "Error: Install path ( ${INSTALL_PATH} ) must be in executable path if it's outside user home directory." && exit 1

    _check_debug

    return 0
}

main() {
    ! [[ ${BASH_VERSINFO:-0} -ge 4 ]] &&
        printf "%s\n" "Error: Bash version lower than 4.x not supported." && exit 1
    _check_dependencies

    set -o errexit -o noclobber -o pipefail

    _variables && _setup_arguments "${@}"

    _check_existing_command() {
        if COMMAND_PATH="$(command -v "${COMMAND_NAME}")"; then
            if export SOURCED_MANGADL=true && . "${COMMAND_PATH}" &&
                [[ -n ${LATEST_INSTALLED_SHA:+${ALL_FILES:+{REPO:+${ALL_FILES}}} ]]; then
                return 0
            else
                printf "%s\n" "Error: Cannot validate existing installation, make sure no other program is installed as ${COMMAND_NAME}."
                printf "%s\n\n" "You can use -c / --cmd flag to specify custom command name."
                printf "%s\n\n" "Create a issue on github with proper log if above mentioned suggestion doesn't work."
                exit 1
            fi
        else
            return 1
        fi
    }

    if [[ -n "${UNINSTALL}" ]]; then
        { _check_existing_command && _uninstall; } ||
            { "${QUIET:-_print_center}" "justify" "mangadl-bash is not installed." "="; }
        exit 0
    else
        "${SKIP_INTERNET_CHECK:-_check_internet}"
        { _check_existing_command && _start update; } || {
            _start install
        }
    fi

    return 0
}

main "${@}"
