#!/usr/bin/env bash

# A setting that causes an error and terminates processing when an undefined variable 
# (a variable to which no value has been assigned) is referenced.
set -u

# This is a Bash option setting. It ensures that if no files match a wildcard, 
# the pattern string itself is treated as an empty string rather than being left as-is.
shopt -s nullglob

# To prevent multiple instances from running..
LOCKFILE="/tmp/$(basename "$0").lock"
exec 9>"$LOCKFILE"
flock -n 9 || {
    echo "Already running: $0" >&2
    exit 9
}

# To display the current date and time.
date

# Set enviroment to execute python packege.
export DATASET_CONFIG="${HOME}/work_local/data_pipeline/mmo/pwi/efd/pds/config/dataset_pwi_efd.json"
source ~/work_local/.3_13/bin/activate

# Set the work directory
WDIR="${HOME}/work_local/data_pipeline/mmo/pwi/efd/efd_spec"

# Set the L1_prome data directory
L1_PRIMEPATH="${HOME}/work_local/data_org/bc/mmo/pwi/efd/l1_prime"

# Set the L2 data directory
L2_BASE="${HOME}/work_local/mmodata/cdf/pwi/efd/l2"

# Set the directory of the common scripts and template file to generate PDS label files.
PDS_PIPELINE_DIR="${HOME}/work_local/pds_pipeline/common/examples/scripts"
TEMPLATEPATH="${HOME}/work_local/pds_pipeline/common/examples/templates"
TEMPLATE_NAME="mmo_cdf_label_template_multi_dataset.xml.j2"
TEMPLATE_FILE="${TEMPLATEPATH}/${TEMPLATE_NAME}"
LABEL_GENERATOR="${LABEL_GENERATOR:-${PDS_PIPELINE_DIR}/make_pds_label_for_mmo_cdf_data.sh}"

# Set the directory of the common scripts to generate PDS collection files.
COLLECTION_GENERATOR="${COLLECTION_GENERATOR:-${PDS_PIPELINE_DIR}/create_psa_collection_jinja.sh}"
COLLECTION_PATH="${COLLECTION_PATH:-/var/www/html/data/chs/satellite/mmo/pds4/bc_mmo_pwi/data_calibrated_efd}"
COLLECTION_FILE_NAME="${COLLECTION_FILE_NAME:-data_calibrated_efd}"

# Set the directory to put on generated PDS label files.
PDS_SCIENCE_BASE="${PDS_SCIENCE_BASE:-/var/www/html/data/chs/satellite/mmo/pds4/bc_mmo_pwi/data_calibrated_efd/science}"

# Set the variable MISSION_PHASE_NAME.
# If the variable MISSION_PHASE_NAME is empty, Cruise is assinged as the default value.
 MISSION_PHASE_NAME="${MISSION_PHASE_NAME:-Cruise}"

# Set the variable MISSION_PHASE_ID.
# If the variable MISSION_PHASE_ID is empty, cruise is assinged as the default value.
 MISSION_PHASE_ID="${MISSION_PHASE_ID:-cruise}"

# Set the document-product references.
# If each variable is empty, the document LIDVID related to EFD data is aggisned as the default value.
PWI_USER_GUIDE_LIDVID="${PWI_USER_GUIDE_LIDVID:-urn:jaxa:darts:bc_mmo_pwi:document:pwi_data_user_guide::1.0}"
PWI_CALIBRATION_GUIDE_LIDVID="${PWI_CALIBRATION_GUIDE_LIDVID:-urn:jaxa:darts:bc_mmo_pwi:document:pwi_efd_calibration_guide::1.0}"

# Set the SPICE Kernel-product references.
# If each variable is empty, the SPICE Kernel LIDVID used for EFD data production is aggisned as the default value.
BC_MMO_LSK_LIDVID="${BC_MMO_LSK_LIDVID:-urn:esa:psa:bc_spice:spice_kernels:lsk_naif0012.tls::1.0}"
BC_MMO_SCLK_LIDVID="${BC_MMO_SCLK_LIDVID:-urn:esa:psa:bc_spice:spice_kernels:sclk:bc_mmo_stre_20250305_v01.tsc::1.0}"
BC_MMO_FK_LIDVID="${BC_MMO_FK_LIDVID:-urn:esa:psa:bc_spice:spice_kernels:fk_bc_mmo_v14.tf::1.0}"

# The raw L1p data reference is generated inside PROCESS_MODE from the exact
# input filename used for each L2 product. Do not define it as a fixed value.
# Map the L1p filename version to the PDS VID used by the archived L1p product.
l1_filename_version_to_pds_vid()
{
    # Store the argument (the first value passed to the function) in the local variable `filename_version`.
    local filename_version="$1"

    # If the version string is r01-v00-00, r01-v01-00, or r02-v01-00, output "1.0" 
    # to standard output (using printf) and terminate successfully.
    case "$filename_version" in
        r01-v00-00|r01-v01-00|r02-v01-00)
            printf '%s\n' "1.0"
            ;;
        *)
            echo \
                "ERROR: No PDS VID mapping for L1p version: $filename_version" \
                >&2
            return 1
            ;;
    esac
}

# Set the version of L1_prome data.
# If each variable L1_PRIMEVER is empty, r01-v00-00 is aggisned as the default value.
L1_PRIMEVER="${L1_PRIMEVER:-r01-v00-00}"

# Set the version of L2 data.
L2VER="r01-v00-00"

# Set the start date to create L2 CDF data and PDS label files.
MIN_DATE="20181001"

# Change to the directory specified by the path stored in the variable $WDIR.
# Implement error handling for movement failures.
cd "$WDIR" || {
    echo "ERROR: Cannot change directory: $WDIR" >&2
    exit 1
}

# It checks whether the label generation program ($LABEL_GENERATOR) exists and 
# has execute permissions (-x). If the file is missing or lacks the necessary permissions,
# it outputs an error and exits with a status of 1 (abnormal termination).
[[ -x "$LABEL_GENERATOR" ]] || {
    echo \
        "ERROR: Label generator is not executable: $LABEL_GENERATOR" \
        >&2
    exit 1
}

# Checking for the existence of the PDS label metadata template file (-f).
[[ -f "$TEMPLATE_FILE" ]] || {
    echo "ERROR: Label template not found: $TEMPLATE_FILE" >&2
    exit 1
}

# Create a base directory to store scientific data in PDS format. 
mkdir -p "$PDS_SCIENCE_BASE"

# By default, "Bulk update of all data" is set to disabled (0).
ALL_UPDATE=0

# If "all" is specified as the first argument ($1) of the script (e.g., `./script.sh all`),
# the ALL_UPDATE flag is set to 1 (enabled).
[[ ${1:-} == "all" ]] && ALL_UPDATE=1

# Set this global flag when a PDS label is created, updated, or removed.
# The collection files are regenerated only when this flag is 1.
COLLECTION_UPDATE_REQUIRED=0

# Logging of setting values.
echo "L1p version filter: $L1_PRIMEVER"
echo "L2 output version : $L2VER"

#####################################################################
# Generate L2 CDF and PDS label files for L and M mode observations.
#####################################################################
process_mode()
{
    # Stores the observation mode (l or m) passed via the first argument ($1).
    local mode="$1"
    
    # Set the directory of L2 CDF files.
    local l2_path="${L2_BASE}/${mode}/spec"
    
    # Set the make script of L2 CDF files.
    local mk_script="${WDIR}/mk_efd_l2_${mode}-spec_cdf.sh"

    # The full path and filename of the L1p input file currently being processed in the loop.
    # The date (YYYYMMDD), calendar year (YYYY), and month (MM) extracted from the file name.
    local input_file input_name ymd yyyy mm
    
    # year_dir: Annual folder names to match the PDS directory structure
    # pds_science_dir: Directory path for storing the final PDS standard data
    local year_dir pds_science_dir

    # source_cdf: Path to the generated original L2 CDF file.
    # pds_cdf: Destination path for the copy of the CDF file placed on the PDS tree side.
    # pds_label: Path of the generated PDS4-format label file (.lblx)
    local source_cdf pds_cdf pds_label

    # A temporary variable used when processing PDS4 Internal_Reference (links to related documents or source data).
    local reference

    # l1_filename_version: Version string extracted from the input file name.
    # l1_pds_vid: Version ID (e.g., 1.0) converted to the PDS4 standard.
    # pwi_data_raw_efd_lidvid: A PDS4-specific identifier pointing to the source data (L1 raw data).
    local l1_filename_version l1_pds_vid pwi_data_raw_efd_lidvid

    # pds_cdf_changed: A flag (0 or 1) indicating whether the contents of the CDF file have been updated.
    # label_update_required: A flag (0 or 1) indicating whether the label (.lblx) needs to be regenerated.
    local pds_cdf_changed label_update_required

    # Search for the target L1p (Level 1 Prime) CDF input files using wildcards (globbing) 
    # and store them all at once in the `input_files` array.
    local -a input_files=(
        "${L1_PRIMEPATH}"/????/bc_mmo_pwi-efd_l1p_"${mode}"-spec_????????_"${L1_PRIMEVER}".cdf
    )

    # Error handling that checks the number of elements in the `input_files` array, outputs a helpful error message 
    # if no target L1p files are found, and safely terminates the function.
    if (( ${#input_files[@]} == 0 )); then
        echo "ERROR: No L1p input files found for ${mode}-mode." >&2
        echo "L1p version   : $L1_PRIMEVER" >&2
        echo "Search pattern: ${L1_PRIMEPATH}/????/bc_mmo_pwi-efd_l1p_${mode}-spec_????????_${L1_PRIMEVER}.cdf" >&2
        return 1
    fi

    # Declare two empty arrays to dynamically construct the Internal_Reference (link information to related documents 
    # or source data) used in generating PDS4 labels.
    local -a internal_references=()
    local -a reference_args=()

    # Strictly verify in advance whether the shell script ($mk_script) that actually generates the L2 (Level 2) CDF file 
    # is executable (i.e., it exists and has execute permissions).
    [[ -x "$mk_script" ]] || {
        echo \
            "ERROR: CDF generation script is not executable: $mk_script" \
            >&2
        return 1
    }

   # Outputting a progress log to notify the user that loop processing (data generation, synchronization, 
   # and label creation) for each file is starting.
    echo "Processing ${mode}-mode..."

    # Iterate through the array `input_files`, sequentially assigning the full path of each stored CDF file to the variable `input_file`.
    for input_file in "${input_files[@]}"; do

        # Remove the entire directory path from the full file path to extract only the filename (equivalent to the result of `basename`) 
        # and store it in the variable `input_name`.
        input_name=${input_file##*/}

        # Use Bash's regular expression matching (`=~`) to strictly verify that L1p filenames adhere to the naming convention, 
        # while simultaneously extracting the necessary metadata in a single operation.
        if [[ "$input_name" =~ ^bc_mmo_pwi-efd_l1p_([lm])-spec_([0-9]{8})_(r[0-9]+-v[0-9]+-[0-9]+)\.cdf$ ]]; then
            [[ "${BASH_REMATCH[1]}" == "$mode" ]] || continue
            ymd="${BASH_REMATCH[2]}"
            l1_filename_version="${BASH_REMATCH[3]}"
        else
            echo "WARNING: Unsupported L1p filename: $input_file" >&2
            continue
        fi

        # A filtering process that determines whether the extracted data matches the target version and dates from the specified start date or later, 
        # skipping (continuing) the processing of the file if these conditions are not met.
        [[ "$l1_filename_version" == "$L1_PRIMEVER" ]] || continue
        (( 10#$ymd < 10#$MIN_DATE )) && continue

        # Convert the L1p file version to a PDS4 standard version (VID), and use this to dynamically construct the "LIDVID" 
        # (Logical Identifier + Version Identifier)—the most critical data identifier in PDS4.
        l1_pds_vid="$(l1_filename_version_to_pds_vid "$l1_filename_version")" || continue

        # Construction of the "LIDVID" (Logical Identifier + Version Identifier)—the unique identifier for data products under the PDS4 standard—using 
        # the PDS version number ($l1_pds_vid) successfully generated in the previous step.
        pwi_data_raw_efd_lidvid="urn:jaxa:darts:bc_mmo_pwi:data_raw_efd:bc-mmo-pwi_raw_sc_efd_l1_${mode}-spec_${ymd}::${l1_pds_vid}"

        # Consolidate all external reference information (documents, SPICE kernels, source data, etc.) into the `internal_references` 
        # array in accordance with PDS4 specifications.
        internal_references=(
            "${PWI_USER_GUIDE_LIDVID}|data_to_document"
            "${PWI_CALIBRATION_GUIDE_LIDVID}|data_to_document"
            "${BC_MMO_LSK_LIDVID}|data_to_spice_kernel"
            "${BC_MMO_SCLK_LIDVID}|data_to_spice_kernel"
            "${BC_MMO_FK_LIDVID}|data_to_spice_kernel"
            "${pwi_data_raw_efd_lidvid}|data_to_raw_product"
        )

        # Extract the first four characters from the variable ${ymd} (e.g., 20260921) to obtain the year (2026).
        yyyy=${ymd:0:4}
        
        # Extract two characters starting from the fourth character of the variable ${ymd} to obtain the month (09).
        mm=${ymd:4:2}

        # Generate a yearly folder name commonly used in PDS4 (e.g., 20260101_20261231).
        year_dir="${yyyy}0101_${yyyy}1231"

        # Determine the final storage directory within the PDS4 archive tree.
        pds_science_dir="${PDS_SCIENCE_BASE}/${year_dir}"

        # The full path of the original L2 CDF file generated first within the pipeline.
        source_cdf="${l2_path}/${yyyy}/${mm}/bc_mmo_pwi-efd_l2_${mode}-spec_${ymd}_${L2VER}.cdf"

        # Path of the CDF file placed (copied) in the PDS4 tree.
        pds_cdf="${pds_science_dir}/$(basename "$source_cdf")"

        # Path to the PDS4-format **XML metadata label file (.lblx)** corresponding to the CDF file.
        pds_label="${pds_science_dir}/$(basename "${source_cdf%.cdf}").lblx"

        # Automatically create two directories in advance: one for the generated L2 CDF files 
        # and another for the final PDS4 archive output.
        mkdir -p \
            "$(dirname "$source_cdf")" \
            "$pds_science_dir"

        # An initialization process that performs a complete clean build (batch regeneration) by forcibly 
        # deleting all existing output files (L2 CDF, PDS CDF, and PDS labels) beforehand if "all" is 
        # specified as a script startup argument (when ALL_UPDATE=1).
        if (( ALL_UPDATE )); then
            rm -f \
                "$source_cdf" \
                "$pds_cdf" \
                "$pds_label"
        fi
        
        ## Generation of L2 CDF file if there is no input naming CDF file or newer one.##
        if [[ ! -e "$source_cdf" ||
              "$input_file" -nt "$source_cdf" ]]; then
            "$mk_script" -v "$L2VER" "$ymd" || {
                echo \
                    "ERROR: CDF generation failed: $ymd (${mode}-mode)" \
                    >&2
                continue
            }
        fi

        # Synchronize the generated L2 CDF and label with the PDS4 tree.
        pds_cdf_changed=0
        label_update_required=0

        # A safety function that verifies the results of the L2 CDF generation script ($mk_script) executed 
        # in the preceding step and automatically cleans up old files (orphaned files) if no output artifacts 
        # are found.
        if [[ ! -f "$source_cdf" ]]; then
            echo "WARNING: L2 CDF does not exist: $source_cdf" >&2

            if [[ -e "$pds_cdf" ]]; then
                echo "Removing stale PDS CDF: $pds_cdf"
                rm -f "$pds_cdf"
            fi

            if [[ -e "$pds_label" ]]; then
                echo "Removing stale PDS label: $pds_label"
                if rm -f "$pds_label"; then
                    COLLECTION_UPDATE_REQUIRED=1
                else
                    echo "ERROR: Failed to remove stale PDS label: $pds_label" >&2
                fi
            fi

            continue
        fi

        # Comparing file contents, not only mtimes. This catches updates whose
        # timestamps were preserved during copy or generation.
        if [[ ! -f "$pds_cdf" ]]; then
            echo "PDS CDF does not exist. Copying the L2 CDF."
            pds_cdf_changed=1
        elif ! cmp -s "$source_cdf" "$pds_cdf"; then
            echo "L2 CDF content changed. Updating the PDS CDF."
            pds_cdf_changed=1
        else
            echo "PDS CDF content is up to date."
        fi

        if (( pds_cdf_changed )); then
            cp -fp "$source_cdf" "$pds_cdf" || {
                echo "ERROR: Failed to copy CDF: $source_cdf" >&2
                continue
            }
            label_update_required=1
        fi

        [[ -f "$pds_cdf" ]] || {
            echo "ERROR: PDS CDF does not exist after synchronization: $pds_cdf" >&2
            continue
        }

        # Regenerate the label when its CDF or label-generation inputs changed.
        if [[ ! -f "$pds_label" ]]; then
            label_update_required=1
        elif (( pds_cdf_changed )); then
            label_update_required=1
        elif [[ "$pds_cdf" -nt "$pds_label" ]]; then
            label_update_required=1
        elif [[ "$TEMPLATE_FILE" -nt "$pds_label" ]]; then
            label_update_required=1
        elif [[ "$LABEL_GENERATOR" -nt "$pds_label" ]]; then
            label_update_required=1
        fi

        # Converting the necessary external reference information into safe command arguments 
        # and passing them to the label generation program ($LABEL_GENERATOR).
        if (( label_update_required )); then

            # Initialize (create) an empty array named `reference_args`.
            reference_args=()

            # A process that iterates through the `internal_references` array and 
            # populates a separate array, `reference_args`, with only the valid, 
            # non-empty elements, formatted according to specific options.
            for reference in "${internal_references[@]}"; do
  
                # This is a guard clause that checks if the variable `reference` is **empty 
                # (length of 0)**; if so, it **skips the subsequent processing and proceeds 
                # to the next iteration of the loop (continue)**.
                [[ -n "$reference" ]] || continue

                # Each time a valid reference is found, append (+=) a pair of elements—the 
                # option name `--internal-reference` and **its value (`$reference`)**—to the 
                # end of the pre-prepared empty array `reference_args`.
                reference_args+=(
                    --internal-reference
                    "$reference"
                )
            done

            # Output the script execution status and metadata of the target being analyzed 
            # to the screen (standard output) as a log.
            echo "L1p source         : $input_file"
            echo "L1p filename ver.  : $l1_filename_version"
            echo "L1p PDS VID        : $l1_pds_vid"
            echo "L1p data reference : $pwi_data_raw_efd_lidvid"
            echo "Internal references:"

            for reference in "${internal_references[@]}"; do
                echo "  $reference"
            done
            
            ###############################################################################
            # The core (main processing) component that executes the label generation tool 
            # (LABEL_GENERATOR) using the assembled arguments and various variables.
            ###############################################################################
            if "$LABEL_GENERATOR" \
                "$pds_cdf" \
                "$TEMPLATEPATH" \
                "$TEMPLATE_NAME" \
                "$pds_science_dir" \
                --mission-phase-name "$MISSION_PHASE_NAME" \
                --mission-phase-id "$MISSION_PHASE_ID" \
                "${reference_args[@]}"
            then
                # A label was successfully created or regenerated.
                COLLECTION_UPDATE_REQUIRED=1
                echo "PDS label was created or updated: $pds_label"
            else
                # Skip this day if label generation fails / 失敗したらこの日は飛ばす
                echo \
                    "ERROR: Label generation failed: $ymd (${mode}-mode)" \
                    >&2
                continue
            fi
        else
            echo "PDS label is up to date."
        fi

        # A validation check to verify whether the label file ($pds_label)—which should 
        # have been generated in the preceding step—actually exists on the disk.
        [[ -f "$pds_label" ]] || {
            echo "ERROR: Label does not exist: $pds_label" >&2
            continue
        }

        # Output the log to successfully finish generating PDS label files.
        echo "Completed: $ymd (${mode}-mode)"
        echo
    done
}

process_mode "l"
process_mode "m"

echo
echo "$0 completed label generation."
date

#####################################################################
# Update PDS collection files only when a label was created, updated,
# or removed during this run.
#####################################################################
if (( COLLECTION_UPDATE_REQUIRED )); then
    echo
    echo "PDS label changes were detected."
    echo "Updating collection files..."

    if "$COLLECTION_GENERATOR" \
        "$COLLECTION_FILE_NAME" \
        "$COLLECTION_PATH"
    then
        echo
        echo "Completed updating collection files."
    else
        echo "ERROR: Failed to update collection files." >&2
        exit 1
    fi
else
    echo
    echo "No PDS label changes were detected."
    echo "Collection update was skipped."
fi

date
