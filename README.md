# BruteNiB (Brute Force Negative Image-Based Rescoring)

The BruteNiB script evaluates the impact of each cavity point (or
atom) in a cavity-based negative image or NIB model for the negative
image-based rescoring (R-NiB) of explicit PLANTS docking poses.  If
the removal of any of the points/atoms improves the R-NiB yield, the
corresponding line is removed from the NIB model permanently.  The
iterative remove & evaluate process with the outputted model is done
to each point/atom using a systematic brute force approach.

## Dependencies

Installation requires C++ compiler that supports **C++11**.

For example, RHEL 7 (and CentOS Linux 7, etc) can get modern GCC compiler in *Developer Toolset* from Software Collections.

Running requires that commands 'rocker' and 'shaep' are on the path.
* ROCKER: http://www.medchem.fi/rocker/
* ShaEP: http://users.abo.fi/mivainio/shaep/

## Installation

Open package contents into a directory.

Run `make` in that directory.  You need a C++ compiler that supports C++11.

You can have brutenib.sh's location on PATH, set alias to the script, etc.

```
# make folder for binaries:
mkdir brute
# make it current
cd brute
# unpack package (2020-02-05 is version and will change)
tar xf path-to/brutenib-2020-02-05.tar.gz

make

# append folder to path
export PATH=${PATH}:brute
# OR set alias
alias brutenib.sh=brute/brutenib.sh
# OR use full path when calling brutenib.sh
```

## Usage

Make a working directory.  Call the `brutenib.sh` in that directory.
It will show what options are required.
