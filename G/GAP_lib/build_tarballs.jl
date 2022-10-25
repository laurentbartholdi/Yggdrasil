# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

# The version of this JLL is decoupled from the upstream version.
# Whenever we package a new upstream release, we initially map its
# version X.Y.Z to X00.Y00.Z00 (i.e., multiply each component by 100).
# So for example version 2.6.3 would become 200.600.300.
#
# Moreover, all our packages using this JLL use `~` in their compat ranges.
#
# Together, this allows us to increment the patch level of the JLL for minor tweaks.
# If a rebuild of the JLL is needed which keeps the upstream version identical
# but breaks ABI compatibility for any reason, we can increment the minor version
# e.g. go from 200.600.300 to 200.601.300.
# To package prerelease versions, we can also adjust the minor version; e.g. we may
# map a prerelease of 2.7.0 to 200.690.000.
#
# There is currently no plan to change the major version, except when upstream itself
# changes its major version. It simply seemed sensible to apply the same transformation
# to all components.

name = "GAP_lib"
upstream_version = v"4.12.1"
version = v"400.1201.100"

# Collection of sources required to complete build
sources = [
    ArchiveSource("https://github.com/gap-system/gap/releases/download/v$(upstream_version)/gap-$(upstream_version)-core.tar.gz",
                  "1e8e823578e8f1018af592b39bd6f3be1402b482d98f1efb3e24fe6e2f55c926"),
    ArchiveSource("https://github.com/gap-system/gap/releases/download/v$(upstream_version)/packages-required-v$(upstream_version).tar.gz",
                  "86d24a1a2208d57822b9aed159b2d5c1306e1a800c6440c6a0d4566e65829c57";
                  unpack_target="pkg"),
]

# Bash recipe for building across all platforms
script = raw"""
cd ${WORKSPACE}/srcdir/gap*

mv ../pkg .

# must run autogen.sh if compiling from git snapshot and/or if configure was patched;
# it doesn't hurt otherwise, too, so just always do it
./autogen.sh

# compile a native version of GAP so we can use it to generate the manual
# (the manual is only in FULL gap release tarballs, not in the -core tarball
# nor in git snapshots), and also so that we can invoke the
# `install-gaproot` target (which is arch independent, so no need to use a
# GAP built for the host arch.)
./configure --prefix=${prefix} --build=${MACHTYPE} --host=${MACHTYPE} \
    --with-gmp=${prefix} \
    --without-readline \
    --with-zlib=${prefix} \
    CC=${CC_BUILD} CXX=${CXX_BUILD}
make -j${nproc}

# build the manual if necessary (only HTML and txt; for PDF we'd need LaTeX)
if [[ ! -f doc/ref/chap0.html ]] ; then
  make html
fi

# the license
install_license LICENSE

# install documentation and library files
make install-doc install-gaproot
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = [AnyPlatform()]

# The products that we will ensure are always built
products = Product[
]

# Dependencies that must be installed before this package can be built
dependencies = [
    BuildDependency("Zlib_jll"),
    BuildDependency("GMP_jll"),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
