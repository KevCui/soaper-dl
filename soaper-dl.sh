#!/usr/bin/env bash
#
# Download TV series and Movies from Soaper using CLI
#
#/ Usage:
#/   ./soaper-dl.sh [-n <name>] [-p <path>] [-e <num1,num2,num3-num4...>] [-l] [-s] [-d]
#/
#/ Options:
#/   -n <name>               TV series or Movie name
#/   -p <path>               media path, e.g: /tv_XXXXXXXX.html
#/                           ingored when "-n" is enabled
#/   -e <num1,num3-num4...>  optional, episode number to download
#/                           e.g: episode number "3.2" means Season 3 Episode 2
#/                           multiple episode numbers seperated by ","
#/                           episode range using "-"
#/   -l                      optional, list video or subtitle link without downloading
#/   -s                      optional, download subtitle only
#/   -d                      enable debug mode
#/   -h | --help             display this help message

set -e
set -u

usage() {
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" && exit 1
}

set_var() {
    _CURL="$(command -v curl)" || command_not_found "curl"
    _JQ="$(command -v jq)" || command_not_found "jq"
    _PUP="$(command -v pup)" || command_not_found "pup"
    _FZF="$(command -v fzf)" || command_not_found "fzf"
    _FFMPEG="$(command -v ffmpeg)" || command_not_found "ffmpeg"

    _HOST="https://soaper.tv"
    _SEARCH_URL="$_HOST/search/keyword/"

    _SCRIPT_PATH=$(dirname "$(realpath "$0")")
    _SEARCH_LIST_FILE="${_SCRIPT_PATH}/search.list"
    _SOURCE_FILE=".source.html"
    _EPISODE_LINK_LIST=".episode.link"
    _EPISODE_TITLE_LIST=".episode.title"
    _MEDIA_HTML=".media.html"
    _SUBTITLE_LANG="${SOAPER_SUBTITLE_LANG:-en}"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hlsdn:x:p:e:" opt; do
        case $opt in
            n)
                _INPUT_NAME="${OPTARG// /%20}"
                ;;
            p)
                _MEDIA_PATH="$OPTARG"
                ;;
            e)
                _MEDIA_EPISODE="$OPTARG"
                ;;
            l)
                _LIST_LINK_ONLY=true
                ;;
            s)
                _DOWNLOAD_SUBTITLE_ONLY=true
                ;;
            d)
                _DEBUG_MODE=true
                set -x
                ;;
            h)
                usage
                ;;
            \?)
                print_error "Invalid option: -$OPTARG"
                ;;
        esac
    done
}

print_info() {
    # $1: info message
    printf "%b\n" "\033[32m[INFO]\033[0m $1" >&2
}

print_warn() {
    # $1: warning message
    printf "%b\n" "\033[33m[WARNING]\033[0m $1" >&2
}

print_error() {
    # $1: error message
    printf "%b\n" "\033[31m[ERROR]\033[0m $1" >&2
    exit 1
}

command_not_found() {
    # $1: command name
    print_error "$1 command not found!"
}

sed_remove_space() {
    sed -E '/^[[:space:]]*$/d;s/^[[:space:]]+//;s/[[:space:]]+$//'
}

download_media_html() {
    # $1: media link
    "$_CURL" -sS "${_HOST}${1}" > "$_SCRIPT_PATH/$_MEDIA_NAME/$_MEDIA_HTML"
}

get_media_name() {
    # $1: media link
    "$_CURL" -sS "${_HOST}${1}" \
        | $_PUP ".panel-body h4 text{}" \
        | head -1 \
        | sed_remove_space
}

search_media_by_name() {
    # $1: media name
    local d t len l n lb
    d="$("$_CURL" -sS "${_SEARCH_URL}$1")"
    t="$($_PUP ".thumbnail" <<< "$d")"
    len="$(grep -c "class=\"thumbnail" <<< "$t")"
    [[ -z "$len" || "$len" == "0" ]] && print_error "Media not found!"

    true > "$_SEARCH_LIST_FILE"
    for i in $(seq 1 "$len"); do
        n="$($_PUP ".thumbnail:nth-child($i) h5 a:nth-child(1) text{}" <<< "$t" | sed_remove_space)"
        l="$($_PUP ".thumbnail:nth-child($i) h5 a:nth-child(1) attr{href}" <<< "$t" | sed_remove_space)"
        lb="$($_PUP --charset UTF-8 ".thumbnail:nth-child($i) .label-info text{}" <<< "$t" | sed_remove_space)"
        echo "[$l][$lb] $n" | tee -a "$_SEARCH_LIST_FILE"
    done
}

is_movie() {
    # $1: media path
    [[ "$1" =~ ^/movie_.* ]] && return 0 || return 1
}

download_source() {
    local d a
    mkdir -p "$_SCRIPT_PATH/$_MEDIA_NAME"
    d="$("$_CURL" -sS "${_HOST}${_MEDIA_PATH}")"
    a="$($_PUP ".alert-info-ex" <<< "$d")"
    if is_movie "$_MEDIA_PATH"; then
        download_media "$_MEDIA_PATH" "$_MEDIA_NAME"
    else
        echo "$a" > "$_SCRIPT_PATH/$_MEDIA_NAME/$_SOURCE_FILE"
    fi
}

download_episodes() {
    # $1: episode number string
    local origel el uniqel se
    origel=()
    if [[ "$1" == *","* ]]; then
        IFS="," read -ra ADDR <<< "$1"
        for n in "${ADDR[@]}"; do
            origel+=("$n")
        done
    else
        origel+=("$1")
    fi

    el=()
    for i in "${origel[@]}"; do
        if [[ "$i" == *"-"* ]]; then
            se=$(awk -F '-' '{print $1}' <<< "$i" | awk -F '.' '{print $1}')
            s=$(awk -F '-' '{print $1}' <<< "$i" | awk -F '.' '{print $2}')
            e=$(awk -F '-' '{print $2}' <<< "$i" | awk -F '.' '{print $2}')
            for n in $(seq "$s" "$e"); do
                el+=("${se}.${n}")
            done
        else
            el+=("$i")
        fi
    done

    IFS=" " read -ra uniqel <<< "$(printf '%s\n' "${el[@]}" | sort -u -V | tr '\n' ' ')"

    [[ ${#uniqel[@]} == 0 ]] && print_error "Wrong episode number!"

    for e in "${uniqel[@]}"; do
        download_episode "$e"
    done
}

download_episode() {
    # $1: episode number
    local l
    l=$(grep "\[$1\] " "$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_LINK_LIST" \
        | awk -F '] ' '{print $2}')
    [[ "$l" != *"/"* ]] && print_error "Wrong download link or episode not found!"
    download_media "$l" "$1"
}

download_media() {
    # $1: media link
    # $2: media name
    local u d el sl p
    download_media_html "$1"
    is_movie "$_MEDIA_PATH" && u="GetMInfoAjax" || u="GetEInfoAjax"
    p="$(sed 's/.*e_//;s/.html//' <<< "$1")"
    d="$("$_CURL" -sS "${_HOST}/home/index/${u}" \
        -H "referer: https://${_HOST}${1}" \
        --data-raw "pass=${p}&param=ddd&extra=&e2=0")"
    el="$($_JQ -r '.val' <<< "$d")"
    [[ "$el" != *".m3u8" ]] && el="$($_JQ -r '.val_bak' <<< "$d")"
    if [[ "$($_JQ '.subs | length' <<< "$d")" -gt "0" ]]; then
        sl="$($_JQ -r '.subs[]| select(.name | contains ("'"$_SUBTITLE_LANG"'")) | .path' <<< "$d")"
    fi

    if [[ -z ${_LIST_LINK_ONLY:-} ]]; then
        if [[ -n "${sl:-}" ]]; then
            print_info "Downloading subtitle $2..."
            "$_CURL" "${sl}" > "$_SCRIPT_PATH/${_MEDIA_NAME}/${2}_${_SUBTITLE_LANG}.srt"
        fi
        if [[ -z ${_DOWNLOAD_SUBTITLE_ONLY:-} ]]; then
            print_info "Downloading video $2..."
            "$_FFMPEG" -i "$el" -c copy -v error -y "$_SCRIPT_PATH/${_MEDIA_NAME}/${2}.mp4"
        fi
    else
        if [[ -z ${_DOWNLOAD_SUBTITLE_ONLY:-} ]]; then
            echo "$el"
        else
            if [[ -n "${sl:-}" ]]; then
                echo "${sl}"
            fi
        fi
    fi
}

create_episode_list() {
    local slen sf t l sn et el
    sf="$_SCRIPT_PATH/$_MEDIA_NAME/$_SOURCE_FILE"
    el="$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_LINK_LIST"
    et="$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_TITLE_LIST"
    slen="$(grep 'alert alert-info-ex' -c "$sf")"
    true > "$et"
    true > "$el"
    for i in $(seq "$slen" -1 1); do
        sn=$((slen - i + 1))
        t="$($_PUP ".alert-info-ex:nth-child($i) div text{}" < "$sf" \
            | sed_remove_space \
            | tac \
            | awk '{print "[" num  "." NR "] " $0}' num="${sn}")"
        l="$($_PUP ".alert-info-ex:nth-child($i) div a attr{href}" < "$sf" \
            | sed_remove_space \
            | tac \
            | awk '{print "[" num  "." NR "] " $0}' num="${sn}")"
        echo "$t" >> "$et"
        echo "$l" >> "$el"
    done
}

select_episodes_to_download() {
    cat "$_SCRIPT_PATH/$_MEDIA_NAME/$_EPISODE_TITLE_LIST" >&2
    echo -n "Which episode(s) to downolad: " >&2
    read -r s
    echo "$s"
}

main() {
    set_args "$@"
    set_var

    local mlist=""
    if [[ -n "${_INPUT_NAME:-}" ]]; then
        mlist="$(search_media_by_name "$_INPUT_NAME")"
        _MEDIA_PATH=$($_FZF -1 <<< "$(sort -u <<< "$mlist")" | awk -F']' '{print $1}' | sed -E 's/^\[//')
    fi

    [[ -z "${_MEDIA_PATH:-}" ]] && print_error "Media not found! Missing option -n <name> or -p <path>?"
    [[ ! -s "$_SEARCH_LIST_FILE" ]] && print_error "$_SEARCH_LIST_FILE not found. Please run \`-n <name>\` to generate it."
    _MEDIA_NAME=$(sort -u "$_SEARCH_LIST_FILE" \
                | grep "$_MEDIA_PATH" \
                | awk -F '] ' '{print $2}' \
                | sed -E 's/\//_/g')

    [[ "$_MEDIA_NAME" == "" ]] && _MEDIA_NAME="$(get_media_name "$_MEDIA_PATH")"

    download_source

    is_movie "$_MEDIA_PATH" && exit 0

    create_episode_list

    [[ -z "${_MEDIA_EPISODE:-}" ]] && _MEDIA_EPISODE=$(select_episodes_to_download)
    download_episodes "$_MEDIA_EPISODE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
