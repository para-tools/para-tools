#!/bin/bash -eu
this_dir="$(realpath -m "$(dirname "$(readlink -f "$0")")")"
#orig_dir="$(pwd)"   #< Uncomment if we need to access files relative to the user's pwd
cd "$this_dir"

###################################################################
#
# Configuration for .deb package
#

pkg_name="para-tools"
pkg_version="0.0.1"
pkg_revision="2"
pkg_arch="all"

description="A collection of simple scripts for assisting with code development"
pkg_maintainer="Mac Harwood <MacHarwood@gmail.com>"

out_dist_dir="_out_dist"

###################################################################
#
# Combined values
#

tag="v${pkg_version}-r${pkg_revision}"
full_pkg_name="${pkg_name}_${pkg_version}-${pkg_revision}_${pkg_arch}"

###################################################################
#
# Git & Release locations
#
git_hash="$(git describe --always --dirty)"
git_remote_name="$(git remote -v | head -n 1 | awk '{print $2}')" #< eg: git@github.com:Mac-H/para-tools.git
git_remote_url="${git_remote_name/git@github.com:/https:\/\/github.com\/}"

git_url_prefix="${git_remote_url%.git}/"

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

if [[ "$git_hash" == *-dirty ]]; then
    echo "⚠️ Warning: Git repository has uncommitted changes.  Consider committing or stashing changes before creating a release."
fi

###################################################################
#
# Standard from here onwards for building a Debian package
#
dest_dir="${out_dist_dir}/${full_pkg_name}"

opt_dir="/opt/${pkg_name}"

rm -rf "${dest_dir:-MISSING}/$opt_dir"
mkdir -p "$dest_dir/$opt_dir"
mkdir -p "$dest_dir/DEBIAN"
printf "#!/bin/bash -eu\n\n echo \n echo 'Installing the following commands:'\n" > "$dest_dir/DEBIAN/postinst"
printf "#!/bin/bash -eu\n\n echo \n echo 'Removing the following commands:'\n" > "$dest_dir/DEBIAN/prerm"


chmod +x "$dest_dir/DEBIAN/postinst"
chmod +x "$dest_dir/DEBIAN/prerm"

cp "${this_dir%/}/LICENSE" "$dest_dir/$opt_dir/"

readarray -t readme_lines < "${this_dir%/}/readme.md"
{
    #
    # Readme top section
    # The exception is the 'Installing the latest version' section,
    # which we want to include as it contains useful information about getting the latest release.
    #
    first_header_is_found='no'
    for line in "${readme_lines[@]}"; do
        if [[ "$line" == "# "* ]] ; then
            [[ "$first_header_is_found" == "yes" ]] && break
            first_header_is_found='yes'
        fi
        echo "$line"
    done

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
    printf "echo 'Release information:'\n"
    printf "echo ' • This release can be found at      : %s  (Git Hash: %s)'\n" "${git_release_info_url}" "${git_hash}"
    printf "echo ' • The latest release can be found at: %s'\n" "${git_releases_all_url}/latest"
    printf "echo ''\n"
    printf "echo 'To remove: sudo dpkg -r %s'\n" "$pkg_name"
} >> "$dest_dir/DEBIAN/postinst"

{
    printf "echo ''\n"
    printf "echo 'To reinstall:'\n"
    printf "echo ' • This exact version: %s (Git Hash: %s)'\n" "${git_release_info_url}" "${git_hash}"
    printf "echo ' • The latest version: %s'\n" "${git_releases_all_url}/latest"
} >> "$dest_dir/DEBIAN/prerm"



##############################################
# Generate the release notes for this package
#
{
    cat "${this_dir%/}/release-notes-template.md"  \
        | sed "s|<version>|${pkg_version}|g" \
        | sed "s|<full_pkg_name>|${full_pkg_name}|g" \
        | sed "s|<tag>|${tag}|g" \
        | sed "s|<package_download_url>|${package_download_url}|g" \
        | sed "s|<git_hash>|${git_hash}|g"

    echo ""

    #
    # Readme headlines (Basically everything before the first subtitle)
    #
    for line in "${readme_lines[@]}"; do
        [[ "$line" == "##"* ]] && break

        echo "$line"
    done

} > "${out_dist_dir%/}/${tag}_release_notes.md"
echo "✅  Created Release notes : ${out_dist_dir%/}/${tag}_release_notes.md   (Release Tag: ${tag})"

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
echo " • Get basic information with: dpkg-deb --info     ${dest_dir}.deb"
echo " • Review contents with      : dpkg-deb --contents ${dest_dir}.deb"
echo " • Install with              : sudo dpkg -i ${dest_dir}.deb"
echo " • Uninstall with            : sudo dpkg -r ${pkg_name}"
echo " • Rebuild with              : $0"
echo ""
echo "To publish this release:"
echo "   git tag            ${tag} && \\"
echo "   git push origin    ${tag} && \\"
echo "   gh  release create ${tag} ${dest_dir}.deb --title \"Release ${tag}\" -F \"${out_dist_dir%/}/${tag}_release_notes.md\""
