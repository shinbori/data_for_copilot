#!/usr/bin/env bash
#
# Usage:
#   mk_efd_l2_l-spec_cdf.sh 20181109
#   mk_efd_l2_l-spec_cdf.sh -v r00-v00-00 20181109
#   mk_efd_l2_l-spec_cdf.sh -v r00-v00-00 20181109 20181110
#

set -u

VERSION=""
OUTCDFDIR="${HOME}/work_local/mmodata/cdf/pwi/efd/l2/l/spec"

usage()
{
    echo "Usage: $(basename "$0") [-v VERSION] YYYYMMDD [YYYYMMDD ...]"
}

# ----------------------------------------------------------------------
# オプション処理
# ----------------------------------------------------------------------

while getopts ":v:h" opt; do
    case "$opt" in
        v)
            VERSION="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
        :)
            echo "ERROR: Option -$OPTARG requires an argument." >&2
            usage >&2
            exit 2
            ;;
        \?)
            echo "ERROR: Unknown option: -$OPTARG" >&2
            usage >&2
            exit 2
            ;;
    esac
done

shift $((OPTIND - 1))

# ----------------------------------------------------------------------
# 引数確認
# ----------------------------------------------------------------------

if (( $# == 0 )); then
    usage >&2
    exit 2
fi

# ----------------------------------------------------------------------
# IDL環境設定
# ----------------------------------------------------------------------

BASH_PATH="${HOME}/.bash_path"

if [[ ! -r "$BASH_PATH" ]]; then
    echo "ERROR: Environment file is not readable: $BASH_PATH" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$BASH_PATH"

if ! command -v idl >/dev/null 2>&1; then
    echo "ERROR: idl command was not found." >&2
    exit 1
fi

mkdir -p "$OUTCDFDIR"

# ----------------------------------------------------------------------
# 一時ファイル
# ----------------------------------------------------------------------

TMP_IDLPRO=$(mktemp "${TMPDIR:-/tmp}/efd_l2_l_spec.XXXXXX.pro")

cleanup()
{
    rm -f "$TMP_IDLPRO"
}

trap cleanup EXIT HUP INT TERM

# ----------------------------------------------------------------------
# CDF生成
# ----------------------------------------------------------------------

for ymd in "$@"; do
    if [[ ! $ymd =~ ^[0-9]{8}$ ]]; then
        echo "ERROR: Invalid date format: $ymd" >&2
        echo "       Use YYYYMMDD, for example 20181109." >&2
        continue
    fi

    echo "Processing: $ymd"

    if [[ -n "$VERSION" ]]; then
        version_keyword=", versionstr='${VERSION}'"
    else
        version_keyword=""
    fi

    cat >"$TMP_IDLPRO" <<EOF
makecdf_mmo_pwi_efd_l2_l_spec, ${ymd}${version_keyword}, /debug, outcdfdir='${OUTCDFDIR}/'
exit
EOF

    # デバッグ時に有効化
    # cat "$TMP_IDLPRO"

    if ! nice -n 8 idl "$TMP_IDLPRO"; then
        echo "ERROR: IDL processing failed: $ymd" >&2
        exit 1
    fi
done
