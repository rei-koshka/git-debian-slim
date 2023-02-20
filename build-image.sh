#!/bin/bash

set -e

function build_image() {
  local image_name="$1"
  local image_tag="$2"
  local git_version="$3"
  local supress_errors="$4"

  output_tag_name="git:${git_version}-${image_name}-${image_tag}"

  docker build \
    -t "${output_tag_name}" \
    -f Dockerfile \
    --build-arg "IMAGE_NAME=${image_name}" \
    --build-arg "IMAGE_TAG=${image_tag}" \
    --build-arg "GIT_VERSION=${git_version}" \
    --build-arg "SUPPRESS_ERRORS=${supress_errors}" \
    --progress=plain \
    --target=final \
    .
}

function save_image() {
  local image_name="$1"
  local image_tag="$2"
  local git_version="$3"

  output_name="${git_version}-${image_name}-${image_tag}"

  docker save -o "./git-${output_name}.tar" "git:${output_name}"
}

image_name="debian"
image_tag="stable-slim"
git_version="2.39.2"
suppress_errors="false"
need_save=0

if [ "$1" == "--help" ]; then
  echo
  echo "Builds Git using given Debian-based image."
  echo
  echo "  Parameters:"
  echo "    --image              Debian-based Docker image (default: \`${image_name}:${image_tag}\`)."
  echo "    --git-version        Git version (default: \`${git_version}\`)."
  echo "    --suppress-errors    Proceed even on severe errors with non-zero exit codes (default: \`${suppress_errors}\`)."
  echo "    --save               Save built image as \`.tar\` archive (default: \`${need_save}\`)."
  echo

  exit 0
fi

while [ "$#" != "0" ]; do
  if [ "$1" == "--image" ]; then
    image_name=$(echo "$2" | cut -d ":" -f 1)
    image_tag=$(echo "$2" | cut -d ":" -f 2)

    if [ -z "${image_tag}" ]; then
      image_tag="latest"
    fi

    shift
    shift
  fi

  if [ "$1" == "--git-version" ]; then
    git_version="$2"
    shift
    shift
  fi

  if [ "$1" == "--suppress-errors" ]; then
    suppress_errors="$1"
    shift
  fi

  if [ "$1" == "--save" ]; then
    need_save=1
    shift
  fi
done

build_image "${image_name}" "${image_tag}" "${git_version}" "${suppress_errors}"

if [ "${need_save}" ]; then
  save_image "${image_name}" "${image_tag}" "${git_version}"
fi

exit 0
