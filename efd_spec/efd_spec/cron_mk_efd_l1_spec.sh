#!/usr/bin/env bash

set -u
shopt -s nullglob

LOCKFILE="/tmp/$(basename "$0").lock"
exec 9>"$LOCKFILE"
flock -n 9 || {
    echo "Already running: $0" >&2
    exit 9
}

date

export PYTHONPATH="${HOME}/work_local/pds_pipeline/common/miopds_common${PYTHONPATH:+:$PYTHONPATH}"

L1_BASE="${L1_BASE:-/home/miosc/mio-sc/work_local/data_org/bc/mmo/pwi/efd/l1}"

LABEL_GENERATOR_DIR="${LABEL_GENERATOR_DIR:-${HOME}/work_local/data_pipeline/mmo/pwi/efd/pds/label_generator}"
TEMPLATEPATH="${TEMPLATEPATH:-$LABEL_GENERATOR_DIR}"
TEMPLATE_NAME="${TEMPLATE_NAME:-mmo_cdf_label_template_multi_dataset.xml.j2}"
TEMPLATE_FILE="${TEMPLATEPATH}/${TEMPLATE_NAME}"
LABEL_GENERATOR="${LABEL_GENERATOR:-${LABEL_GENERATOR_DIR}/make_pds_label_for_mmo_cdf_data.sh}"
RENDERER="${LABEL_GENERATOR_DIR}/render_mmo_cdf_label_multi_dataset.py"

PDS_SCIENCE_BASE="${PDS_SCIENCE_BASE:-/var/www/html/data/chs/satellite/mmo/pds4/bc_mmo_pwi/data_raw_efd/science}"

LABEL_PROFILE="${LABEL_PROFILE:-pwi-efd}"
PROCESSING_LEVEL="${PROCESSING_LEVEL:-Raw}"
MISSION_PHASE_NAME="${MISSION_PHASE_NAME:-Cruise}"
MISSION_PHASE_ID="${MISSION_PHASE_ID:-cruise}"
TIME_VARIABLE="${TIME_VARIABLE:-strtime}"
EPOCH_VARIABLE="${EPOCH_VARIABLE:-epoch}"

# Select the structured citation-author file for this instrument.
AUTHORS_FILE="${AUTHORS_FILE:-${LABEL_GENERATOR_DIR}/authors_pwi_efd.json}"

# Document-product references.
PWI_USER_GUIDE_LIDVID="${PWI_USER_GUIDE_LIDVID:-urn:jaxa:darts:bc_mmo_pwi:document:pwi_data_user_guide::1.0}"
PWI_CALIBRATION_GUIDE_LIDVID="${PWI_CALIBRATION_GUIDE_LIDVID:-urn:jaxa:darts:bc_mmo_pwi:document:pwi_efd_calibration_guide::1.0}"

# SPICE Kernel-product references.
# Set these to registered PSA/PDS4 LIDVID values before archive delivery.
BC_MMO_LSK_LIDVID="${BC_MMO_LSK_LIDVID:-urn:esa:psa:bc_spice:spice_kernels:lsk_naif0012.tls::1.0}"
BC_MMO_SCLK_LIDVID="${BC_MMO_SCLK_LIDVID:-urn:esa:psa:bc_spice:spice_kernels:sclk:bc_mmo_stre_20250305_v01.tsc::1.0}"
BC_MMO_FK_LIDVID="${BC_MMO_FK_LIDVID:-urn:esa:psa:bc_spice:spice_kernels:fk_bc_mmo_v14.tf::1.0}"

MIN_DATE="${MIN_DATE:-20181001}"
L1_VERSION_FILTER="${L1_VERSION_FILTER:-r01-v00-00}"

[[ -d "$L1_BASE" ]] || {
    echo "ERROR: L1 directory not found: $L1_BASE" >&2
    exit 1
}

[[ -x "$LABEL_GENERATOR" ]] || {
    echo "ERROR: Label generator is not executable: $LABEL_GENERATOR" >&2
    exit 1
}

[[ -f "$TEMPLATE_FILE" ]] || {
    echo "ERROR: Label template not found: $TEMPLATE_FILE" >&2
    exit 1
}

[[ -f "$RENDERER" ]] || {
    echo "ERROR: Label renderer not found: $RENDERER" >&2
    exit 1
}

[[ -f "$AUTHORS_FILE" ]] || {
    echo "ERROR: Citation authors file was not found: $AUTHORS_FILE" >&2
    exit 1
}

mkdir -p "$PDS_SCIENCE_BASE"

ALL_UPDATE=0
case "${1:-}" in
    "")
        ;;
    all)
        ALL_UPDATE=1
        ;;
    *)
        echo "Usage: $(basename "$0") [all]" >&2
        exit 2
        ;;
esac

echo "L1 source directory : $L1_BASE"
echo "L1 version filter   : $L1_VERSION_FILTER"
echo "PDS processing level: $PROCESSING_LEVEL"
echo "PDS science base    : $PDS_SCIENCE_BASE"

input_files=(
    "$L1_BASE"/????/bc_mmo_pwi-efd_l1_?-spec_????????_"$L1_VERSION_FILTER".cdf
)

if (( ${#input_files[@]} == 0 )); then
    echo "ERROR: No L1 spectrum CDF files were found." >&2
    echo "Search pattern: $L1_BASE/????/bc_mmo_pwi-efd_l1_?-spec_????????_${L1_VERSION_FILTER}.cdf" >&2
    exit 1
fi

status=0

for source_cdf in "${input_files[@]}"; do
    input_name=${source_cdf##*/}

    if [[ "$input_name" =~ ^bc_mmo_pwi-efd_l1_([lmh])-spec_([0-9]{8})_(r[0-9]+-v[0-9]+-[0-9]+)\.cdf$ ]]; then
        mode="${BASH_REMATCH[1]}"
        ymd="${BASH_REMATCH[2]}"
        filename_version="${BASH_REMATCH[3]}"
    else
        echo "WARNING: Unsupported L1 filename: $source_cdf" >&2
        status=1
        continue
    fi

    [[ "$filename_version" == "$L1_VERSION_FILTER" ]] || continue
    (( 10#$ymd >= 10#$MIN_DATE )) || continue

    yyyy=${ymd:0:4}
    year_dir="${yyyy}0101_${yyyy}1231"
    pds_science_dir="${PDS_SCIENCE_BASE}/${year_dir}"
    pds_cdf="${pds_science_dir}/${input_name}"
    pds_label="${pds_science_dir}/${input_name%.cdf}.lblx"

    mkdir -p "$pds_science_dir" || {
        echo "ERROR: Cannot create output directory: $pds_science_dir" >&2
        status=1
        continue
    }

    if (( ALL_UPDATE )); then
        rm -f "$pds_cdf" "$pds_label"
    fi

    pds_cdf_changed=0
    label_update_required=0

    if [[ ! -f "$pds_cdf" ]]; then
        echo "PDS CDF does not exist. Copying the L1 CDF."
        pds_cdf_changed=1
    elif ! cmp -s "$source_cdf" "$pds_cdf"; then
        echo "L1 CDF content changed. Updating the PDS CDF."
        pds_cdf_changed=1
    else
        echo "PDS CDF content is up to date."
    fi

    if (( pds_cdf_changed )); then
        cp -fp "$source_cdf" "$pds_cdf" || {
            echo "ERROR: Failed to copy L1 CDF: $source_cdf" >&2
            status=1
            continue
        }
        label_update_required=1
    fi

    [[ -f "$pds_cdf" ]] || {
        echo "ERROR: PDS CDF does not exist after synchronization: $pds_cdf" >&2
        status=1
        continue
    }

    if [[ ! -f "$pds_label" ]]; then
        label_update_required=1
    elif (( pds_cdf_changed )); then
        label_update_required=1
    elif [[ "$pds_cdf" -nt "$pds_label" ]]; then
        label_update_required=1
    elif [[ "$TEMPLATE_FILE" -nt "$pds_label" ]]; then
        label_update_required=1
    elif [[ "$AUTHORS_FILE" -nt "$pds_label" ]]; then
        label_update_required=1
    elif [[ "$LABEL_GENERATOR" -nt "$pds_label" ]]; then
        label_update_required=1
    elif [[ "$RENDERER" -nt "$pds_label" ]]; then
        label_update_required=1
    fi

    if (( label_update_required )); then
        internal_references=(
            "${PWI_USER_GUIDE_LIDVID}|data_to_document"
            "${PWI_CALIBRATION_GUIDE_LIDVID}|data_to_document"
            "${BC_MMO_LSK_LIDVID}|data_to_spice_kernel"
            "${BC_MMO_SCLK_LIDVID}|data_to_spice_kernel"
            "${BC_MMO_FK_LIDVID}|data_to_spice_kernel"
        )

        reference_args=()
        for reference in "${internal_references[@]}"; do
            [[ -n "$reference" ]] || continue
            reference_args+=(
                --internal-reference
                "$reference"
            )
        done

        echo "L1 source file     : $source_cdf"
        echo "PDS CDF target     : $pds_cdf"
        echo "PDS label target   : $pds_label"
        echo "Mode               : $mode"
        echo "Internal references:"
        for reference in "${internal_references[@]}"; do
            echo "  $reference"
        done

        "$LABEL_GENERATOR" \
            "$pds_cdf" \
            "$TEMPLATEPATH" \
            "$TEMPLATE_NAME" \
            "$pds_science_dir" \
            --profile "$LABEL_PROFILE" \
            --processing-level "$PROCESSING_LEVEL" \
            --time-variable "$TIME_VARIABLE" \
            --epoch-variable "$EPOCH_VARIABLE" \
            --mission-phase-name "$MISSION_PHASE_NAME" \
            --mission-phase-id "$MISSION_PHASE_ID" \
            --authors-file "$AUTHORS_FILE" \
            "${reference_args[@]}" || {
                echo "ERROR: L1 label generation failed: $ymd (${mode}-mode)" >&2
                status=1
                continue
            }
    else
        echo "PDS label is up to date."
    fi

    [[ -f "$pds_label" ]] || {
        echo "ERROR: Expected PDS label was not generated:" >&2
        echo "       $pds_label" >&2
        status=1
        continue
    }

    echo "Completed: $ymd (${mode}-mode)"
    echo
done

echo "$0 completed."
date
exit "$status"
