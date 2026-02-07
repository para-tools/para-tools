#!/bin/bash -eu
# <package_name>_<version>-<revision>_<architecture>


pkg_name="para-tools"
pkg_version="0.0.1"
pkg_revision="1"
pkg_arch="all"

description="A collection of simple scripts for assisting with code development"

out_dist_dir="_out_dist"

github_repo_user="Mac-H"
###################################################################
#
# Release locations
#
tag="v${pkg_version}-r${pkg_revision}"
full_pkg_name="${pkg_name}_${pkg_version}-${pkg_revision}_${pkg_arch}"

git_url_prefix="https://github.com/${github_repo_user}/${pkg_name}"
git_releases_all_url="${git_url_prefix}/releases"
git_release_info_url="${git_url_prefix}/releases/${tag}"
package_download_url="${git_url_prefix}/releases/download/${tag}/${full_pkg_name}.deb"

###################################################################
#
# Standard from here onwards for building a Debian package
#
this_dir="$(realpath -m "$(dirname "$(readlink -f "$0")")")"
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
    for line in "${readme_lines[@]}"; do
        if [[ "$line" == "# Development Notes #"* ]]; then
            echo "## Version Information ##"
            echo " * Version: ${pkg_version}"
            echo " * Revision: ${pkg_revision}"
            break
        fi

        echo "$line"
    done
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
    echo "Maintainer: Mac Harwood <MacHarwood@gmail.com>"
    echo "Description: ${description}"
    # Longer description should be prefixed with a space
} > "$dest_dir/DEBIAN/control"

{
    printf "echo ''\n"
    printf "echo 'Release information:'\n"
    printf "echo ' • This release can be found at      : %s'\n" "${git_release_info_url}"
    printf "echo ' • The latest release can be found at: %s'\n" "${git_releases_all_url}/latest"
    printf "echo ''\n"
    printf "echo 'To remove: sudo dpkg -r %s'\n" "$pkg_name"
} >> "$dest_dir/DEBIAN/postinst"

{
    printf "echo ''\n"
    printf "echo 'To reinstall:'\n"
    printf "echo ' • This exact version: %s'\n" "${git_release_info_url}"
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
        | sed "s|<package_download_url>|${package_download_url}|g"

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
