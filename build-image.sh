#!/bin/bash

set -e

function build_image() {
  local base_image_name="$1"
  local base_image_version="$2"
  local with_docs="$3"
  local with_addons="$4"
  local git_version="$5"
  local lfs_version="$6"
  local src_type="$7"
  local supress_errors="$8"

  local base_line_number=$(grep -n "as base" Dockerfile | cut -d ':' -f 1)
  local base_image="${base_image_name}:${base_image_version}"

  sed -i "${base_line_number}s/.*/FROM ${base_image} as base/" Dockerfile

  local final_image_suffix="${base_image_name}-${base_image_version}"
  local output_tag_name="git:${git_version}-${final_image_suffix}"

  docker buildx build \
    -t "${output_tag_name}" \
    --build-arg="BASE_IMAGE=${base_image}" \
    --build-arg="GIT_VERSION=${git_version}" \
    --build-arg="LFS_VERSION=${lfs_version}" \
    --build-arg="WITH_DOCS=${with_docs}" \
    --build-arg="WITH_ADDONS=${with_addons}" \
    --build-arg="SRC_TYPE=${src_type}" \
    --build-arg="SUPPRESS_ERRORS=${supress_errors}" \
    --target=final \
    --progress=plain \
    --no-cache \
    .
}

function save_image() {
  local base_image_name="$1"
  local base_image_version="$2"
  local git_version="$3"

  local final_image_suffix="${base_image_name}-${base_image_version}"

  output_name="${git_version}-${final_image_suffix}"

  docker save -o "./git-${output_name}.tar" "git:${output_name}"
}

base_image_name="debian"
base_image_version="stable-slim"
git_version="2.39.2"
lfs_version="3.3.0"
with_docs=false
with_addons=false
src_type="remote"
suppress_errors=false
need_save=false

if [ "$1" == "--help" ]; then
  echo
  echo "Builds Git using given Debian-based image."
  echo
  echo "  Parameters:"
  echo "    --base-image         Base image (default: \`${base_image_name}:${base_image_version}\`)."
  echo "    --git-version        Git version (default: \`${git_version}\`)."
  echo "    --lfs-version        Git LFS version (default: \`${lfs_version}\`)."
  echo "    --with-docs          Include docs (default: \`${with_docs}\`)."
  echo "    --with-addons        Include add-ons (Perl, Python, etc.) (default: \`${with_addons}\`)."
  echo "    --src-path           Build from specified source directory, instead of remote tarball."
  echo "    --suppress-errors    Proceed even on severe errors with non-zero exit codes (default: \`${suppress_errors}\`)."
  echo "    --save               Save built image as \`.tar\` archive (default: \`${need_save}\`)."
  echo

  exit 0
fi

while [ "$#" != "0" ]; do
  if [ "$1" == "--base-image" ]; then
    base_image_name="$(echo "$2" | cut -d ':' -f 1)"
    base_image_version="$(echo "$2" | cut -d ':' -f 2)"
    shift
    shift
  fi

  if [ "$1" == "--git-version" ]; then
    git_version="$2"
    shift
    shift
  fi

  if [ "$1" == "--lfs-version" ]; then
    lfs_version="$2"
    shift
    shift
  fi

  if [ "$1" == "--suppress-errors" ]; then
    suppress_errors=true
    shift
  fi

  if [ "$1" == "--save" ]; then
    need_save=true
    shift
  fi

  if [ "$1" == "--with-docs" ]; then
     with_docs=true
    shift
  fi

  if [ "$1" == "--with-addons" ]; then
    with_addons=true
    shift
  fi

  if [ "$1" == "--src-path" ]; then
    src_type="local"
    mkdir src || true
    sudo mount --bind "$2" "src" || true
    shift
    shift
  fi
done

build_image \
  "${base_image_name}" \
  "${base_image_version}" \
  "${with_docs}" \
  "${with_addons}" \
  "${git_version}" \
  "${lfs_version}" \
  "${src_type}" \
  "${suppress_errors}"

if $need_save; then
  save_image \
    "${base_image_name}" \
    "${base_image_version}" \
    "${git_version}"
fi

if [ "${src_type}" == "local" ]; then
  sudo umount -R "src" || true
  rm -rf "src" || true
fi

exit 0
