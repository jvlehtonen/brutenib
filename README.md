# BruteNiB (Brute Force Negative Image-Based Optimization)

The purpose of BruteNiB script is to optimize cavity-based negative images or negative
image-based (NIB) models for their improved docking rescoring use. The input NIB models
can be generated using cavity detection/filling software PANTHER. The rescoring method
titled negative image-based rescoring (R-NiB) relyes on shape/electrostatics similarity
between the docking poses of ligands and the NIB model. The explicit docking poses can
originate from any software, however, by default the script works directly with PLANTS.
During the optimization, the script evaluates the impact of each cavity atom in a NIB
model. If the removal of any of the atoms improves the R-NiB yield, the corresponding
line is removed from the NIB model permanently. The iterative remove & evaluate process
with the outputted model is done to each atom using a systematic greedy search approach
here dubbed as Brute Force Negative Image-Based Optimization (BR-NiB).

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
