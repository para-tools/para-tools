#!/bin/bash -eu
this_dir=$(dirname "$(readlink -f "$0")")

INSTALL_AS_LINK='no'  # Set to 'yes' to create a symlink instead of copying the file
if [[ "$1" == "--symlink" ]]; then
    INSTALL_AS_LINK='yes'
    shift
fi

APP_SOURCE="${1:-}"
DEST_DIR="${2:-}"

if [[ -z "${APP_SOURCE}" ]] || [[ "--help" == *"$*"* ]]; then
    echo "Usage: do-local-install [--symlink] {file.py} [destination_directory]"
    echo " • file.py: The source file to install"
    echo " • destination_directory: The destination directory to install to"
    echo "   (Defaults to whatever common local bin dirs are found in the PATH or common local bin dirs)"
    echo ""
    echo "The python file must:"
    echo " • Be marked as executable (chmod +x)  -and-"
    echo " • Have a shebang line (e.g., #!/usr/bin/env python3)"
    echo ""
    exit 1
fi

srcNoPath="$(basename -- "$APP_SOURCE")"
APP_NAME="${srcNoPath%.*}"


function main()
{

    verify_or_select_DEST_DIR


    ###########################################################
    #
    # Install the app by either copying or symlinking to the DEST_DIR
    #
    unlink  "${DEST_DIR}/${APP_NAME}" 1>/dev/null 2>/dev/null || true
    if [[ "$INSTALL_AS_LINK" == "no" ]]; then
        cp "${this_dir}/${APP_SOURCE}" "${DEST_DIR}/${APP_NAME}"

        kind="copied from"
    else
        ln -s "${this_dir}/${APP_SOURCE}" "${DEST_DIR}/${APP_NAME}"
        kind="symlinked to"
    fi
    echo "✓ Installed \`${APP_NAME}\` to ${DEST_DIR_DISPLAY}  [${kind} ${this_dir}/${APP_SOURCE}]"
    #########################################################
    #
    # Verify installation by running the app with --version
    #
    if  isInPATH "${DEST_DIR}" ; then
        "${APP_NAME}" --version
    else
        "${DEST_DIR}/${APP_NAME}" --version
    fi

}

#############################
#

function isInPATH()
{
    local dir="$1"
    [[ ":${PATH}:" == *":${dir}:"* ]] || [[ ":${PATH}:" == *":${dir}/:"* ]]
}

function verify_or_select_DEST_DIR()
{
    if [[ -z "${DEST_DIR}" ]] ; then

        LOCAL_OPTIONS=(".local/bin" "bin" "scripts" "share" ".local/scripts" )

        DEST_DIR=""
        for option in "${LOCAL_OPTIONS[@]}"; do
            check_dir="${HOME}/${option}"
            if [[ -d "${check_dir}" ]]; then
                if isInPATH "${check_dir}"; then
                    DEST_DIR="${check_dir}"
                    break
                fi
            fi
        done

        if [[ -z "${DEST_DIR}" ]]; then
            echo "❌  Error: No suitable directory found in the PATH. Please add one of the following to the PATH: "
            for option in "${LOCAL_OPTIONS[@]}"; do
                check_dir="${HOME}/${option}"
                if [[ -d "${check_dir}" ]]; then
                    printf "    - %-40s -- Not in Path\n" "${check_dir}"
                else
                    printf "    - %-40s (not found, but you can create it)\n" "${check_dir}"
                fi
            done
            exit 1
        fi

    fi
    DEST_DIR_DISPLAY=$(realpath -m "$DEST_DIR")
    DEST_DIR_DISPLAY="${DEST_DIR_DISPLAY/#$HOME/\~}"

    if [[ ! -d "${DEST_DIR}" ]]; then
        echo "❌  Error: Destination directory ${DEST_DIR} does not exist."
        exit 1
    elif [[ ! -w "${DEST_DIR}" ]]; then
        echo "❌  Error: Destination directory ${DEST_DIR} is not writable."
        exit 1
    elif  ! isInPATH "${DEST_DIR}" ; then

        echo "⚠️  WARNING: Destination directory ${DEST_DIR_DISPLAY} is not in the PATH."
        echo "    You will need to add ${DEST_DIR_DISPLAY} to your PATH to run \`${APP_NAME}\` from anywhere."
        echo "    You can add the following line to your shell profile (e.g., ~/.bashrc or ~/.zshrc):"
        echo "    export PATH=\"${DEST_DIR_DISPLAY/#\~/\$HOME}:\$PATH\""
    fi
}

main "$@"
