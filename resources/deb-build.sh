#!/usr/bin/env bash
set -e
set -x
VERSION=$1
DIST=$2
ARCH=$3
PROJECT_DIR="$(realpath "$(dirname "$0")/../")"
cd "${PROJECT_DIR}" || exit
BUILD_DIR=${PROJECT_DIR}/target/debian/${DIST}
mkdir -p "${BUILD_DIR}"

# https://bugs.launchpad.net/ubuntu/+source/ubuntu-dev-tools/+bug/1964670
sudo sed -i s/pkg-config-\$target_tuple//g /usr/bin/mk-sbuild

# --skip-security because: https://bugs.launchpad.net/ubuntu/+source/ubuntu-dev-tools/+bug/1955116
if [[ "${ARCH}" != "amd64" ]]; then
  mk-sbuild "${DIST}" --target "${ARCH}" --skip-security --type=file || sbuild-update -udc "${DIST}"-amd64-"${ARCH}"
else
  mk-sbuild "${DIST}" --skip-security --type=file || sbuild-update -udc "${DIST}"-amd64
fi

mvn -B versions:set -DnewVersion="${VERSION}" -DgenerateBackupPoms=false
resources/deb-gen-source.sh "${VERSION}" "${DIST}"
if [[ "${ARCH}" != "amd64" ]]; then
  sbuild -v -b -d "${DIST}" --build-dir "${BUILD_DIR}" --no-run-lintian --no-arch-all --host "${ARCH}" "${PROJECT_DIR}"/../jitsi-lgpl-dependencies_*.dsc
else
  sbuild -v -b -d "${DIST}" --build-dir "${BUILD_DIR}" --no-run-lintian --arch-all "${PROJECT_DIR}"/../jitsi-lgpl-dependencies_*.dsc
  cp "${PROJECT_DIR}"/../jitsi-lgpl-dependencies_* "$BUILD_DIR"
fi

debsign -S -edev+maven@jitsi.org "${BUILD_DIR}"/*.changes --re-sign -p"${PROJECT_DIR}"/resources/gpg-wrap.sh

#make build files readable for Windows and archivable for GitHub Actions
rename 's|:|-|g' "$BUILD_DIR"/*.build
