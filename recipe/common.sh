#!/bin/bash
#
# Common build configuration for all HTCondor
# components
#

# if cross compiling, unset the _CONDA_PYTHON_SYSCONFIGDATA_NAME variable
# so that sphinx can use the build-platform's python
if [[ "${build_platform}" != "${target_platform}" ]]; then
  unset _CONDA_PYTHON_SYSCONFIGDATA_NAME
fi

# platform-specific options
if [[ "${target_platform}" == linux* ]]; then
  export LDFLAGS="-ldl -lrt ${LDFLAGS}"
  export CXXFLAGS="${CXXFLAGS} -D_GNU_SOURCE"
  # cmake options
  WITH_MUNGE="TRUE"
else
  # ignore libc++ availability checks
  # see https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
  CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
  # cmake options
  WITH_MUNGE="FALSE"
fi

HTCONDOR_CMAKE_ARGS="
  ${CMAKE_ARGS}
  -D_VERBOSE:BOOL=TRUE
  -DBUILD_DAEMONS:BOOL=TRUE
  -DBUILD_SHARED_LIBS:BOOL=TRUE
  -DBUILD_TESTING:BOOL=FALSE
  -DCMAKE_INSTALL_LIBDIR:STRING=lib
  -DCMAKE_INSTALL_PREFIX:PATH=${PREFIX}
  -DDLOPEN_SECURITY_LIBS:BOOL=FALSE
  -DENABLE_JAVA_TESTS:BOOL=FALSE
  -DHAVE_BOINC:BOOL=FALSE
  -DPROPER:BOOL=TRUE
  -DWANT_MAN_PAGES:BOOL=TRUE
  -DWANT_PYTHON_WHEELS:BOOL=FALSE
  -DWANT_PYTHON2_BINDINGS:BOOL=FALSE
  -DWITH_BLAHP:BOOL=FALSE
  -DWITH_BOINC:BOOL=FALSE
  -DWITH_BOSCO:BOOL=FALSE
  -DWITH_CAMPUSFACTORY:BOOL=FALSE
  -DWITH_CREAM:BOOL=FALSE
  -DWITH_GANGLIA:BOOL=FALSE
  -DWITH_GLOBUS:BOOL=FALSE
  -DWITH_KRB5:BOOL=TRUE
  -DWITH_MUNGE:BOOL=${WITH_MUNGE}
  -DWITH_SCITOKENS:BOOL=TRUE
  -DWITH_VOMS:BOOL=FALSE
"

# strip debug symbols from binaries listed on stdin.
#
# HTCondor's CMake unconditionally forces a RelWithDebInfo (-O2 -g3) build
# regardless of the build type we request -- see the plain (non-cache)
# set() calls in build/cmake/CondorConfigure.cmake, which shadow any
# -DCMAKE_BUILD_TYPE we pass.  conda-build does not strip binaries itself,
# so without this every shipped executable and library carries full -g3
# debug info, which is a significant size overhead.  Upstream expects the
# packaging system to do the stripping ("package may strip the info").
#
# Reads a newline-separated list of paths on stdin and strips any that are
# ELF/Mach-O binaries (other paths, e.g. scripts and data files, are left
# untouched).  Uses the toolchain ${STRIP} so it also works when cross
# compiling.
condor_strip() {
  local _strip="${STRIP:-strip}"
  local _file
  while IFS= read -r _file; do
    [ -f "${_file}" ] || continue
    case "$(file -b "${_file}" 2>/dev/null)" in
      *Mach-O*)
        # a full strip breaks Mach-O dylibs/bundles; -x keeps global symbols
        "${_strip}" -x "${_file}" || true
        ;;
      *ELF*executable*)
        "${_strip}" "${_file}" || true
        ;;
      *ELF*shared*object*)
        "${_strip}" --strip-unneeded "${_file}" || true
        ;;
    esac
  done
}
