#!/bin/bash
# Remove build output inside the Docker environment.
cd "$(dirname "$0")"
docker run --rm -it -v "$PWD":/fos fos-env make clean
