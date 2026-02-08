#!/bin/bash -eu

install_prefix="para-"
install_name="${install_prefix}tools"


#####################################################
#
thisDir="$(realpath -m "$(dirname "$(readlink -f "$0")")")"

dest_dir_top="${1:-}"
dir_files="${2:-}"

[[ -z "$dir_files" ]] && dir_files="${thisDir%/}"

if [[ -z "$dest_dir_top" ]]  || [[ " --help " == *" $* "* ]]; then
    echo "Usage: $0 {top_install_directory} {file source directory} "
    echo "  top_install_directory: The top-level directory to install the tool parts to"
    echo "                         eg: _out/para-tools_0.1.0-1_all/"
    echo "  file_source_directory: The directory containing the files to install "
    echo "                         eg: parts/dir-hash/"
    exit 1
fi


tool_part="${dir_files##*/}"

install_bin_dir="/usr/bin/"
install_opt_dir="/opt/${install_name}/"


#####################################################
#
dest_dir_top="${dest_dir_top%/}/"  # Ensure trailing slash is present
dest_dir="${dest_dir_top}${install_opt_dir%/}/${tool_part}"

mkdir -p "${dest_dir}"
#|Logging| echo "Copying ${tool_part} to ${dest_dir_top#"${PWD}/"} [+ /opt/${install_name}/${tool_part}]"
                                                        #echo " * dest_dir_top: ${dest_dir_top}"
                                                        #echo " * dir_files   : ${dir_files}"
                                                        #echo " * dest_dir    : ${PWD}"

#####################################################
#
# Install the src & readme.md to the destination directory
#
if [[ -d "${dir_files%/}/src" ]] ; then
    #|Logging| echo " ✓ Copy 'src' files"
    cp -r "${dir_files%/}/src/." "${dest_dir}"
fi

for fname in "${dir_files%/}/"* ; do
    [[ -f "$fname" ]] || continue
    base_fname="$(basename -- "$fname")"
    [[ "$base_fname" != "readme.md" ]] && [[ "$base_fname" != "${tool_part}."* ]] && continue
    #|Logging| echo " ✓ Copy '$base_fname' file"
    cp "$fname" "${dest_dir}"
done

######################################################
#
# All installation to /opt is done
#
# Now review the files that were copied

if command -v "tree" &>/dev/null; then

    readarray -t lines < <(tree "${dest_dir}" --noreport | tail -n +2)  # Indent the output for better readability

    if [[ "${#lines[@]}" -eq 0 ]] ; then
        echo "⚠️ WARNING: No files were copied to the destination directory: ${dest_dir}"
        echo "            Please check that the source directory (${dir_files}) contains files to copy."
    fi
    for line in "${lines[@]}"; do
        echo " $line"
    done
fi

######################################################
#
# If there are files that should be linked to from /usr/bin, then create the links and verify the shebang lines of the files to be linked
#
declare -A fileTypes=(
    ['.py']='#!/usr/bin/env python3'
    ['.js']='#!/usr/bin/env node'
    ['.sh']='#!/bin/bash -eu'
)

list_of_files_to_link=()
if [[ -f "${dir_files%/}/create_links.txt" ]] ; then
    #|Logging| echo " ✓ Found 'create_links.txt'"
    readarray -t list_of_files_to_link <<< "$(cat "${dir_files%/}/create_links.txt")"
else

    #|Logging| echo "   No 'create_links.txt' found for ${tool_part} - Choosing automatically"
    execute_this_file=""
    for ext in "${!fileTypes[@]}"; do
        fname="${tool_part}${ext}"
        #|Logging| echo looking for "${fname}" in "${dest_dir}"
        [[ -f "${dest_dir%/}/${fname}" ]] || continue
        list_of_files_to_link+=("|${fname}")
        #echo " ✓ Will create an installation link to $fname"
        break
    done
    if [[ "${#list_of_files_to_link[@]}" == 0 ]] ; then
        echo "⚠️ WARNING: No tool '$tool_part' found (Checked for extensions [${!fileTypes[*]}])"
        echo "             If you don't want a link to be created for this tool part, "
        echo "             you can create an empty 'create_links.txt' file in the tool part."
        exit 1
    fi

fi

for fname in "${list_of_files_to_link[@]}" ; do
    fname="${fname%%#*}"  # Remove comments
    fname="${fname// /}"  # Remove whitespace
    [[ -z "$fname" ]] && continue  # Skip empty lines
    check_shebang='no'
    if [[ "$fname" == "|"* ]] ; then
        check_shebang='yes'
        fname="${fname#|}"  # Remove leading '|'
    fi
    echo "$fname" | grep -E '^[a-zA-Z0-9._-]+$' >/dev/null
    if [[ ! "${PIPESTATUS[0]}" -eq 0 ]] ; then
        echo "❌ Error: Invalid link entry '$fname' in create_links.txt. Only alphanumeric characters, dots, underscores, and hyphens are allowed."
        exit 1
    fi

    execute_this_file="${dest_dir%/}/${fname}"

    if [[ ! -f "${execute_this_file}" ]] ; then
        echo "❌ Error: Not able to install a link: ${fname} does not exist"
        exit 1
    fi
    if [[ ! -x "${execute_this_file}" ]] ; then
        echo "❌ Error: Not able to install a link: ${fname} is not marked as executable (chmod +x)"
        exit 1
    fi

    if [[ "$check_shebang" == "yes" ]] ; then

        extension=".${fname##*.}"

        first_line="$(head -n 1 < "${execute_this_file}")"
        ideal_shebang="${fileTypes[$extension]:-}"

        if [[ -z "$ideal_shebang" ]] ; then
            echo "❌ Error: No ideal shebang found for file extension '$extension'. Please add an entry to the 'fileTypes' array in this script or remove the leading '|' from the filename in create_links.txt if you don't want a shebang check."
            exit 1
        fi
        if [[ "$first_line" != '#!'* ]] ; then
            echo "❌ Error: Unable to install a link: ${fname} must start with a shebang. eg: $ideal_shebang"
            exit 1
        fi

        if [[ ! "$first_line" == "$ideal_shebang" ]] ; then
            echo "⚠️ WARNING: Expected first line of ${fname} to be '$ideal_shebang', but found: $first_line"
        fi
    fi

    install_opt_dir_relative_to_bin_dir="$(realpath "${install_opt_dir}" --relative-to="${install_bin_dir}")"

    mkdir -p "${dest_dir_top%/}/${install_bin_dir}"
    unlink "${dest_dir_top%/}/${install_bin_dir}/${install_prefix}${tool_part}" 1>/dev/null 2>/dev/null || true
    ln -s "${install_opt_dir_relative_to_bin_dir%/}/${tool_part}/${fname}" "${dest_dir_top%/}/${install_bin_dir}/${install_prefix}${tool_part}"
    printf " ✓ Created command: %-20s → %s\n" "${install_prefix}${tool_part}" "$fname"
    if [[ -x "${dest_dir_top%/}/DEBIAN/postinst" ]] ; then
        {
            echo " echo \" • ${install_prefix}${tool_part}\""
        } >> "${dest_dir_top%/}/DEBIAN/postinst"
    fi
    if [[ -x "${dest_dir_top%/}/DEBIAN/prerm" ]] ; then
        {
            echo " echo \" • ${install_prefix}${tool_part}\""
        } >> "${dest_dir_top%/}/DEBIAN/prerm"
    fi
done
