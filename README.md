# BruteNiB (Brute Force Negative Image-Based Rescoring)

The BruteNiB script evaluates the impact of each cavity point (or
atom) in a cavity-based negative image or NIB model for the negative
image-based rescoring (R-NiB) of explicit PLANTS docking poses.  If
the removal of any of the points/atoms improves the R-NiB yield, the
corresponding line is removed from the NIB model permanently.  The
iterative remove & evaluate process with the outputted model is done
to each point/atom using a systematic brute force approach.

## Dependencies

Installation requires C++ compiler that supports **C++11** and CMake (version 3.10 or later).

For example, RHEL 7 (and CentOS Linux 7, etc) has GCC with (sufficient) experimental support,
but can get modern GCC compiler in *Developer Toolset* from Software Collections.

cmake3 for el7 can be found from EPEL repository.

Running requires that commands 'rocker' and 'shaep' are on the path.
* ROCKER: http://www.medchem.fi/rocker/
* ShaEP: http://users.abo.fi/mivainio/shaep/

## Installation

Clone/download repository from GitHub.  Once you have directory `brutenib`:

```
cd brutenib
mkdir build
cd build
cmake3 -DCMAKE_INSTALL_PREFIX=prefix ..
make
make install
```

The install will place files under directory `prefix`. The `-DCMAKE_INSTALL_PREFIX=prefix` is optional.
The default prefix is `/usr/local` and writing there requires admin privileges.
E.g. `sudo make install`.

Ensure that directory `prefix/bin` is on the `PATH`.


## Usage

Make a working directory.  Call the `brutenib` in that directory.
It will show what options are required.
