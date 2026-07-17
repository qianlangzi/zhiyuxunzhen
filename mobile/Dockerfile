FROM ghcr.io/cirruslabs/flutter:stable

ARG ANDROID_NDK_VERSION=30.0.15729638
ARG ANDROID_NDK_ARCHIVE=android-ndk-r30-beta2-linux.zip
ARG ANDROID_NDK_ARCHIVE_SIZE=737229785
ARG ANDROID_NDK_ARCHIVE_SHA1=069427047d18cc6e44369cd7b8e711bfc2c7a3b5

ARG ANDROID_BUILD_TOOLS_VERSION=35.0.0
ARG ANDROID_BUILD_TOOLS_ARCHIVE=build-tools_r35_linux.zip
ARG ANDROID_BUILD_TOOLS_ARCHIVE_SIZE=61958799
ARG ANDROID_BUILD_TOOLS_ARCHIVE_SHA1=2cfaa0bbb2336e9ec18ed3ecea84fa2e2af607bc

RUN set -eux; \
    archive="/tmp/${ANDROID_NDK_ARCHIVE}"; \
    archive_url="https://dl.google.com/android/repository/${ANDROID_NDK_ARCHIVE}"; \
    attempt=1; \
    while [ "${attempt}" -le 30 ]; do \
      curl \
        --fail \
        --location \
        --connect-timeout 30 \
        --retry 5 \
        --retry-all-errors \
        --retry-delay 2 \
        --continue-at - \
        --output "${archive}" \
        "${archive_url}" || true; \
      actual_size="$(stat -c '%s' "${archive}" 2>/dev/null || printf '0')"; \
      if [ "${actual_size}" = "${ANDROID_NDK_ARCHIVE_SIZE}" ] && \
        printf '%s  %s\n' "${ANDROID_NDK_ARCHIVE_SHA1}" "${archive}" | sha1sum -c -; then \
        break; \
      fi; \
      if [ "${actual_size}" -ge "${ANDROID_NDK_ARCHIVE_SIZE}" ]; then \
        rm -f "${archive}"; \
      fi; \
      if [ "${attempt}" -eq 30 ]; then \
        printf 'Unable to download a valid %s after %s attempts.\n' "${ANDROID_NDK_ARCHIVE}" "${attempt}" >&2; \
        exit 1; \
      fi; \
      attempt="$((attempt + 1))"; \
    done; \
    extract_dir=/tmp/android-ndk-extract; \
    ndk_dir="${ANDROID_SDK_ROOT}/ndk/${ANDROID_NDK_VERSION}"; \
    rm -rf "${extract_dir}" "${ndk_dir}"; \
    mkdir -p "${extract_dir}" "$(dirname "${ndk_dir}")"; \
    unzip -q "${archive}" -d "${extract_dir}"; \
    archive_root="$(find "${extract_dir}" -mindepth 1 -maxdepth 1 -type d -name 'android-ndk-*' -print -quit)"; \
    test -n "${archive_root}"; \
    mv "${archive_root}" "${ndk_dir}"; \
    printf '%s\n' \
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
      '<ns2:repository xmlns:ns2="http://schemas.android.com/repository/android/common/02" xmlns:ns5="http://schemas.android.com/repository/android/generic/02">' \
      "  <localPackage path=\"ndk;${ANDROID_NDK_VERSION}\" obsolete=\"false\">" \
      '    <type-details xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="ns5:genericDetailsType"/>' \
      '    <revision><major>30</major><minor>0</minor><micro>15729638</micro><preview>2</preview></revision>' \
      "    <display-name>NDK (Side by side) ${ANDROID_NDK_VERSION}</display-name>" \
      '  </localPackage>' \
      '</ns2:repository>' \
      > "${ndk_dir}/package.xml"; \
    test -x "${ndk_dir}/ndk-build"; \
    grep -F "Pkg.Revision = ${ANDROID_NDK_VERSION}" "${ndk_dir}/source.properties"; \
    sdkmanager --list_installed | grep -F "ndk;${ANDROID_NDK_VERSION}"; \
    rm -rf "${archive}" "${extract_dir}"

RUN set -eux; \
    archive="/tmp/${ANDROID_BUILD_TOOLS_ARCHIVE}"; \
    archive_url="https://dl.google.com/android/repository/${ANDROID_BUILD_TOOLS_ARCHIVE}"; \
    attempt=1; \
    while [ "${attempt}" -le 30 ]; do \
      curl \
        --fail \
        --location \
        --connect-timeout 30 \
        --retry 5 \
        --retry-all-errors \
        --retry-delay 2 \
        --continue-at - \
        --output "${archive}" \
        "${archive_url}" || true; \
      actual_size="$(stat -c '%s' "${archive}" 2>/dev/null || printf '0')"; \
      if [ "${actual_size}" = "${ANDROID_BUILD_TOOLS_ARCHIVE_SIZE}" ] && \
        printf '%s  %s\n' "${ANDROID_BUILD_TOOLS_ARCHIVE_SHA1}" "${archive}" | sha1sum -c -; then \
        break; \
      fi; \
      if [ "${actual_size}" -ge "${ANDROID_BUILD_TOOLS_ARCHIVE_SIZE}" ]; then \
        rm -f "${archive}"; \
      fi; \
      if [ "${attempt}" -eq 30 ]; then \
        printf 'Unable to download a valid %s after %s attempts.\n' "${ANDROID_BUILD_TOOLS_ARCHIVE}" "${attempt}" >&2; \
        exit 1; \
      fi; \
      attempt="$((attempt + 1))"; \
    done; \
    extract_dir=/tmp/android-build-tools-extract; \
    build_tools_dir="${ANDROID_SDK_ROOT}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"; \
    rm -rf "${extract_dir}" "${build_tools_dir}"; \
    mkdir -p "${extract_dir}" "$(dirname "${build_tools_dir}")"; \
    unzip -q "${archive}" -d "${extract_dir}"; \
    archive_root="$(find "${extract_dir}" -mindepth 1 -maxdepth 1 -type d -name 'android-*' -print -quit)"; \
    test -n "${archive_root}"; \
    mv "${archive_root}" "${build_tools_dir}"; \
    printf '%s\n' \
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' \
      '<ns2:repository xmlns:ns2="http://schemas.android.com/repository/android/common/02" xmlns:ns5="http://schemas.android.com/repository/android/generic/02">' \
      "  <localPackage path=\"build-tools;${ANDROID_BUILD_TOOLS_VERSION}\" obsolete=\"false\">" \
      '    <type-details xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="ns5:genericDetailsType"/>' \
      '    <revision><major>35</major><minor>0</minor><micro>0</micro></revision>' \
      '    <display-name>Android SDK Build-Tools 35</display-name>' \
      '  </localPackage>' \
      '</ns2:repository>' \
      > "${build_tools_dir}/package.xml"; \
    test -x "${build_tools_dir}/aapt2"; \
    test -x "${build_tools_dir}/apksigner"; \
    grep -F "Pkg.Revision=${ANDROID_BUILD_TOOLS_VERSION}" "${build_tools_dir}/source.properties"; \
    "${build_tools_dir}/aapt2" version; \
    sdkmanager --list_installed | grep -F "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"; \
    rm -rf "${archive}" "${extract_dir}"

WORKDIR /workspace/mobile

ENV PUB_CACHE=/workspace/.pub-cache

CMD ["sh", "-lc", "flutter pub get && flutter analyze && flutter test"]
