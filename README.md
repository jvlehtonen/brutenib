Installation

Open package contents into a directory.

Run 'make' in that directory.  You need a C++ compiler that supports C++11.

Ensure that commands 'rocker' and 'shaep' are on the path.

You can have brutenib.sh's location on PATH, set alias to the script, etc.

Usage

Make a working directory.  Call the 'brutenib.sh' in that directory.
It will show what options are required.

# make folder for binaries:
mkdir brute
# make it current
cd brute
# unpack package (2020-02-05 is version and will change)
tar xf path-to/brutenib-2020-02-05.tar.gz

# IF default GCC supports C++11
make
# ELSE
# on RHEL 7 / CentOS 7, where new GCC is in Software collection:
scl enable devtoolset-8 make

# append folder to path
export PATH=${PATH}:brute
# OR set alias
alias brutenib.sh=brute/brutenib.sh
# OR use full path when calling brutenib.sh


Make a working directory for a project and run brtenib.sh there
