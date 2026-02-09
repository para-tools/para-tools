#!/bin/bash -eu
this_dir="$(realpath -m "$(dirname "$(readlink -f "$0")")")"
orig_dir="$(pwd)"   #< Uncomment if we need to access files relative to the user's pwd


this_dir_rel="$(realpath -m --relative-to="$orig_dir" "$this_dir")"

cd "$this_dir"

###################################################################
#
# Configuration for .deb package
#

pkg_name="para-tools"
pkg_version="0.0.1"
pkg_revision="" #< Determine this automatically based on git tags
pkg_arch="all"

description="A collection of simple scripts for assisting with code development"
pkg_maintainer="Mac Harwood <MacHarwood@gmail.com>"

out_dist_subdir="_out_dist"


function main()
{

    additional_actions=""
    if [[ "${1:-}" == "--and-install" ]] ; then
        additional_actions+="[install]"
        shift 1 || true
    fi
    ###################################################################
    #
    # Combined values
    #
        readarray -t revList <<< "$(git  -C "$this_dir" tag -l "v${pkg_version}-r*" | sed 's|^.*-r||g' | sort -n)"
    if [[ -z "${pkg_revision:-}" ]] ; then
    {
        echo "Reviewing existing tags for ${pkg_version}:"
        echo " • Existing revisions      : [$(echo "${revList[*]}" | tr ' ' ',')]"
        pkg_revision="1"
        [[ "${#revList[@]}" -eq 0 ]] || pkg_revision=$((revList[-1] + 1))
        echo " • Marking this as revision: ${pkg_revision}"
    }
    fi

    git_hash="$(git -C "$this_dir" describe --always --dirty)"

    tag="v${pkg_version}-r${pkg_revision}"
    full_pkg_name="${pkg_name}_${pkg_version}-${pkg_revision}_${pkg_arch}"

    out_dist_dir="$(realpath -m "${this_dir%/}/${out_dist_subdir}")"
    #out_dist_dir_rel="$(realpath -m --relative-to="$orig_dir" "$out_dist_dir")"

    ###################################################################
    #
    # Git & Release locations
    #
    git_hash="$(git -C "$this_dir" describe --always --dirty)"
    git_remote_name="$(git -C "$this_dir" remote -v | head -n 1 | awk '{print $2}')" #< eg: git@github.com:Mac-H/para-tools.git
    git_remote_url="${git_remote_name/git@github.com:/https:\/\/github.com\/}"

    git_url_prefix="${git_remote_url%.git}/"

    direct_info_page=''
    direct_info_url=''
    doco_git=''
    if [[ "$git_remote_url" == "https://github.com/para-tools/para-tools.git" ]] ; then
        doco_git="${git_remote_name%.git}.github.io.git"
        direct_info_page="para-tools.github.io"
    fi

    [[ -n "$direct_info_page" ]] && direct_info_url="https://${direct_info_page}"

    if [[ "$git_remote_url" == "https://github.com/"* ]] ; then
        true #< This is the default case we expect
    elif [[ "$git_remote_url" == "https://bitbucket.org/"* ]] ; then
        echo "⚠️ Warning: Release locations in bitbucket are untested  - Please verify the URLs manually"
    elif [[ "$git_remote_url" == "https://gitlab.com/"* ]] ; then
        echo "⚠️ Warning: Release locations in gitlab are untested - Please verify the URLs manually"
    else
        echo "⚠️ Warning: Release locations based on $git_remote_url as not supported.  Please update the script to handle this case."
    fi

    git_releases_all_url="${git_url_prefix%/}/releases"
    git_release_info_url="${git_url_prefix%/}/releases/tag/${tag}"
    package_download_url="${git_url_prefix%/}/releases/download/${tag}/${full_pkg_name}.deb"
    git_release_latest_url="${git_url_prefix%/}/releases/latest"

    if [[ -n "$git_release_latest_url" ]] ; then
        # Ensure readme is correct
        sed -i "s|[[]releases/latest[]][(].*[)]|[releases/latest]($git_release_latest_url)|g" "${this_dir%/}/readme.md"
    fi
    echo "ℹ️  Creating package for release: ${git_release_info_url}   (Git Hash: ${git_hash})"

    #|x| if [[ "$git_hash" == *-dirty ]]; then
    #|x|     echo "⚠️ Warning: Git repository has uncommitted changes.  Consider committing or stashing changes before creating a release."
    #|x| fi

    ###################################################################
    #
    # Standard from here onwards for building a Debian package
    #
    dest_dir="${out_dist_dir}/${full_pkg_name}"
    dest_dir_rel="$(realpath -m --relative-to="$orig_dir" "$dest_dir")"

    opt_dir="/opt/${pkg_name}"

    rm -rf "${dest_dir:-MISSING}/$opt_dir"
    mkdir -p "$dest_dir/$opt_dir"
    mkdir -p "$dest_dir/DEBIAN"
    printf "#!/bin/bash -eu\n\n echo \n echo 'Installing the following commands:   (Created with GitHash %s)'\n" "$git_hash" > "$dest_dir/DEBIAN/postinst"
    printf "#!/bin/bash -eu\n\n echo \n echo 'Removing the following commands:   (Created with GitHash %s)'\n" "$git_hash" > "$dest_dir/DEBIAN/prerm"


    chmod +x "$dest_dir/DEBIAN/postinst"
    chmod +x "$dest_dir/DEBIAN/prerm"

    cp "${this_dir%/}/LICENSE" "$dest_dir/$opt_dir/"

    ##########################################################
    #
    # Generate summary documentation for this release (eg: README.md)
    #  * readme_allLines: All lines from the readme
    #  * readme_firstSectionMainOnly: Lines from the first section of the readme - Excluding any subsections (eg: ## Subsection)
    #  * readme_firstSectionSubsections: Lines from the first section of the readme - Only the subsections (eg: ## Subsection) and their content,
    #
    readarray -t readme_allLines < "${this_dir%/}/readme.md"
    readme_firstSectionMainOnly=()
    readme_firstSectionSubsections=()
    {
        first_header_is_found='no'
        am_in_subsections='no'
        for line in "${readme_allLines[@]}"; do
            [[ "$line" == "## "* ]] && am_in_subsections='yes'
            if [[ "$line" == "# "* ]] ; then
                [[ "$first_header_is_found" == "yes" ]] && break
                first_header_is_found='yes'
            fi
            if [[ "$am_in_subsections" == "no" ]] ; then
                readme_firstSectionMainOnly+=("$line")
            else
                readme_firstSectionSubsections+=("$line")
            fi
        done
    }

    #####################################################################
    #
    #
    {
        print_lines "${readme_firstSectionMainOnly[@]}"

        echo "## Version Information ##"
        echo " * Version: ${pkg_version}"
        echo " * Revision: ${pkg_revision}"
        echo " * Git Hash: ${git_hash}"
    } > "$dest_dir/$opt_dir/readme.md"

    for tool_dir in "${this_dir%}/parts"/*/ ; do
        #echo "Processing tool dir: $tool_dir"
        tool_dir="${tool_dir%/}"  # Remove trailing slash
        tool_part="${tool_dir##*/}" # Get the last part of the path
        [[ "$tool_part" == "_out"* ]] && continue

        ##########################################
        #echo "Processing tool part: $tool_part"
        cmd=()
        if [[ -x "${tool_dir}/copy_for_package.sh" ]] ; then
            printf " • Tool part: %-30s   -- Running custom   'copy_for_package.sh'\n" "$tool_part"
            cmd=("${tool_dir}/copy_for_package.sh" "$dest_dir")
        else
            printf " • Tool part: %-30s\n" "$tool_part" #|Logging|   -- Running standard 'copy_for_package.sh'\n" "$tool_part"
            cmd=("${this_dir%/}/installer/copy_for_package.sh" "$dest_dir" "${tool_dir}")
        fi

        if [[ "${#cmd[@]}" != 0 ]] ; then
            "${cmd[@]}" 2>&1 | sed "s/^/             /"  #  │ Indent the output for better readability
            result="${PIPESTATUS[0]}"
            if [[ "$result" -ne 0 ]]; then
                echo "❌ Error: 'copy_for_package.sh' for tool part '$tool_part' failed with exit code $result"
                exit 1
            fi
        fi
    done
    #############################################################
    #
    # Generate DEBIAN entries
    {
        echo "Package: ${pkg_name}"
        echo "Version: ${pkg_version}-${pkg_revision}"
        echo "Architecture: ${pkg_arch}"
        echo "Maintainer: ${pkg_maintainer}"
        echo "Description: ${description}"
        # Longer description should be prefixed with a space
    } > "$dest_dir/DEBIAN/control"

    {
        printf "echo ''\n"
        if [[ -n "$direct_info_url" ]] ; then
            printf "echo 'For more information (including the latest version): %s'\n" "$direct_info_url"
        else
            printf "echo 'Release information:'\n"
            printf "echo ' • This release can be found at      : %s  (Git Hash: %s)'\n" "${git_release_info_url}" "${git_hash}"
            printf "echo ' • The latest release can be found at: %s'\n" "${git_releases_all_url}/latest"
            printf "echo ''\n"
        fi
        printf "echo 'To remove: sudo dpkg -r %s'\n" "$pkg_name"
    } >> "$dest_dir/DEBIAN/postinst"

    {
        printf "echo ''\n"
        if [[ -n "$direct_info_url" ]] ; then
            printf "echo 'To reinstall:  %s'\n" "$direct_info_url/#installing"
        else
            printf "echo 'To reinstall:'\n"
            printf "echo ' • This exact version: %s (Git Hash: %s)'\n" "${git_release_info_url}" "${git_hash}"
            printf "echo ' • The latest version: %s'\n" "${git_releases_all_url}/latest"
        fi
    } >> "$dest_dir/DEBIAN/prerm"



    ##############################################
    # Generate the release notes for this package
    #
    {
        {
            echo "## Installing  ##"
            do_var_replacements < "${this_dir%/}/doc-templates/snippet-installing.md"
            echo "----"
            echo "**This is built from GitHash \`${git_hash}\`**"
            echo ""

            print_lines "${readme_firstSectionMainOnly[@]}"
            print_lines "${readme_firstSectionSubsections[@]}"

        } > "${out_dist_dir%/}/${tag}_release_notes.md"
        echo "✅  Created Release notes : ${out_dist_dir%/}/${tag}_release_notes.md   (Release Tag: ${tag})"
    }

    if [[ -n "$direct_info_page" ]] ; then
        echo "✅  Update source for $direct_info_url"
        {
            print_lines "${readme_firstSectionMainOnly[@]}"
            echo ""
            echo "## Installing ##"
            cat "${this_dir%/}/doc-templates/snippet-installing.md"
            echo ""
            print_lines "${readme_firstSectionSubsections[@]}"
            echo ""
            echo "# More information #"
            echo " * Source code is available at **[<git_url_prefix_url-sans_https>(<git_url_prefix_url>)**"
            echo " * Release history is available at **[<git_releases_all_url-sans_https>](<git_releases_all_url>)**"
        } | do_var_replacements > "${out_dist_dir%/}/${direct_info_page%/}.README.md"
    fi

    ##############################################
    # Build Package
    #
    dpkg-deb --build --root-owner-group "$dest_dir" > /dev/null
    echo "✅  Created Debian package: ${dest_dir}.deb"

    ##############################################
    # Summarise
    #

    echo "╭──────────────────────────────────────────────────────────────────────────────────────────"
    sed "s/^/│ /g" "$dest_dir/DEBIAN/control"
    echo "╰──────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "What next:"
    echo " • Get basic information with: dpkg-deb --info     ${dest_dir_rel}.deb"
    echo " • Review contents with      : dpkg-deb --contents ${dest_dir_rel}.deb"
    echo " • Install with              : sudo dpkg -i ${dest_dir_rel}.deb"
    echo " • Uninstall with            : sudo dpkg -r ${pkg_name}"
    echo " • Rebuild with              : $0"
    echo ""
    {
        #################################################################################################
        # Summarise the release information for the user to easily copy/paste for publishing the release
        #

        comment='' ;
        [[ "$git_hash" == *-dirty ]]    && comment="# " && echo "⚠️  Git repository has uncommitted changes.  Do not publish this release until it has been pushed to the origin"
        _found="$(git tag -l "${tag}" 2>&1)" && [[ -n "$_found" ]] && comment="# " && echo "⚠️  Tag ${tag} already exists.  Consider updating the tag or incrementing the version/revision."
        echo "To publish this release:   (Git hash: ${git_hash/-dirty/⚠️-dirty})"
        echo "\`\`\`"
        {
            [[ "${this_dir_rel%/}" == "." ]] || printf "{\n   pushd \"%s\" >/dev/null \n\n" "${this_dir_rel%/}"
            echo "   ${comment}git push                            && \\"
            echo "   ${comment}git tag                      ${tag} && \\"
            echo "   ${comment}git push origin    refs/tags/${tag} && \\"
            echo "   ${comment}gh  release create           ${tag}   ${out_dist_subdir%/}/${full_pkg_name}.deb --title \"Release ${tag}\" -F \"${out_dist_subdir%/}/${tag}_release_notes.md\" --verify-tag && \\"

            io_page_subdir=''
            if [[ -n "$doco_git" ]] ; then
                io_page_subdir="_externals/${direct_info_page}"

                if [[ ! -f "${this_dir%/}/${io_page_subdir%/}/README.md" ]] ; then
                    echo "   ${comment}mkdir -p \"${io_page_subdir}\" && \\"
                    echo "   ${comment}git clone \"${doco_git}\" \"${io_page_subdir%/}/\" && \\"
                fi
                echo "   ${comment}cp \"${out_dist_subdir%/}/${direct_info_page%/}.README.md\" \"${io_page_subdir%/}/README.md\"  && \\"
                echo "   ${comment}git -C \"${io_page_subdir%/}\" add README.md && \\"
                echo "   ${comment}git -C \"${io_page_subdir%/}\" commit -m \"Update README for Release ${tag} & GitHash ${git_hash}\" && \\"
                echo "   ${comment}git -C \"${io_page_subdir%/}\" push  && \\"
                echo "   ${comment}echo \"✅  Created and pushed release ${tag}   (Git hash: ${git_hash})\""
            else
                echo "   ## Push ${out_dist_subdir%/}/${direct_info_page%/}.README.md to the website: ${direct_info_page%/}/README.md"
            fi
            [[ "${this_dir_rel%/}" == "." ]] || printf "   popd >/dev/null\n}\n"
        } | align_right_continuations
        echo "\`\`\`"
    }
    if [[ "$additional_actions" == *"[install]"* ]] ; then
        echo ""
        echo "Installing package..."
        sudo dpkg -i "${dest_dir}.deb"
    fi
}

function align_right_continuations() {
    local max_line_length=0
    local lines=()

    while IFS= read -r line; do
        lines+=("$line")
        local line_length=${#line}
        if [[ $line_length -gt $max_line_length ]]; then
            max_line_length=$line_length
        fi
    done

    for line in "${lines[@]}"; do
        continuation_marker=" && \\"  # The && continuation mark
        main_line="${line%"$continuation_marker"}"  # Get the part before the continuation mark
        if [[ "$main_line" == "$line" ]] ; then
            continuation_marker=" \\"  # The continuation mark
            main_line="${line%"$continuation_marker"}"  # Get the part before the continuation mark
            [[ "$main_line" == "$line" ]] && continuation_marker=""  # If no continuation mark, set it to empty
        fi
        pad_len=$((max_line_length - ${#continuation_marker}))
        printf "%-${pad_len}s%s\n" "$main_line" "$continuation_marker"
    done
}
function _inner_do_var_replacement_lines() {
    local needle="$1"
    local replacement="$2"

    shift 2 || true
    print_lines "$@" | sed "s|${needle}|${replacement}|g"
}



function _inner_do_var_replacement_file() {
    local needle="$1"
    local replacement="$2"

    local fname="$3"

    local _lines
    readarray -t _lines < "$fname"

    _inner_do_var_replacement_lines "$needle" "$replacement" "${_lines[@]}" > "$fname"
}

function do_var_replacements(){
    declare -A replacements=(
        ["version"]="${pkg_version}"
        ["full_pkg_name"]="${full_pkg_name}"
        ["tag"]="${tag}"
        ["git_hash"]="${git_hash}"
        ["package_download_url"]="${package_download_url}"
        ["git_url_prefix_url"]="${git_url_prefix}"
        ["git_release_info_url"]="${git_release_info_url}"
        ["git_releases_all_url"]="${git_releases_all_url}"
    )

    local _tmpfile ; _tmpfile="$(mktemp)"
    cat > "$_tmpfile"
    for name in "${!replacements[@]}"; do
        _inner_do_var_replacement_file "<${name}>" "${replacements[$name]}" "$_tmpfile"
        [[ "$name" == *_url ]] && _inner_do_var_replacement_file "<${name}-sans_https>" "${replacements[$name]#https://}" "$_tmpfile"
    done
    cat "$_tmpfile"
    rm -f "$_tmpfile"
}

function print_lines(){
    while [[ "$#" -gt 0 ]]; do
        echo "$1"
        shift 1 || true
    done
}


main "$@"
