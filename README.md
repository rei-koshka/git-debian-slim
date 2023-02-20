Git Docker Image (Debian-based)
===

# What
Configuration to build Git from source of specified version as Docker image.

# How to build
* ```bash
  chmod +x build-image.sh
  ./build-image.sh
  ```
* ```
  Parameters:
    --image              Debian-based Docker image (default: `debian:stable-slim`).
    --git-version        Git version (default: `2.39.2`).
    --suppress-errors    Proceed even on severe errors with non-zero exit codes (default: `false`).
    --save               Save built image as `.tar` archive (default: `0`).
  ```
