# BR-NiB (Brute Force Negative Image-Based Optimization)

Negative image-based rescoring (R-NiB) is a docking rescoring method that relyes on shape/
electrostatic potential similarity between the docking poses of ligands and the cavity-based
negative images. The purpose of BR-NiB (Brute Force Negative Image-Based Optimization) or 
the brutenib script is to optimize the cavity atom compositions of the negative image-based
(NIB) models for their improved docking rescoring use. 

The input NIB models for BR-NiB can be generated using cavity detection/filling software 
PANTHER (http://www.medchem.fi/panther/). The explicit docking poses can originate from any
docking software (Autodock, AutodockVina, Glide etc.), however, by default the script works 
directly with PLANTS and ChEMBL database-based DUD and DUD-E training/test sets.

During the optimization, the BR-NiB script evaluates the impact of each cavity atom in the
NIB model for docking enrichment. If the removal of any of the atoms improves the R-NiB yield,
the corresponding line is removed from the NIB model permanently. The iterative remove and
evaluate process with the outputted model is done to each atom using a systematic greedy
search approach here dubbed as BR-NiB.

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


## How to cite BR-NiB and R-NiB methods

1. For BR-NiB: 
      Kurkinen et al. 2022; J Chem Inf Model; ACCEPTED.
      doi: XXX; https
2. For R-NiB:
      Kurkinen et al. 2019; J Chem Inf Model; 59(8):3584-3599.
      doi: 10.1021/acs.jcim.9b00383; https://pubs.acs.org/doi/10.1021/acs.jcim.9b00383 
      Kurkinen et al. 2018; Front Pharmacol; 9:260.
      doi: 10.3389/fphar.2018.00260; https://www.frontiersin.org/articles/10.3389/fphar.2018.00260/full 
 
## Other related & useful publications for BR-NiB usage

1. For PANTHER: 
      Niinivehmas et al., 2015; J Comput Aided Mol Des; 29(10):989-1006; 
      doi: 10.1007/s10822-015-9870-3; https://link.springer.com/article/10.1007%2Fs10822-015-9870-3
2. For ShAEP: 
      Vainio et al., 2009; J Chem Inf Model; 49(2):492-502;
      doi: 10.1021/ci800315d; https://pubs.acs.org/doi/10.1021/ci800315d
3. For ROCKER:
      Lätti et al., 2016; J Cheminform; 8(1):45.
      doi: 10.1186/s13321-016-0158-y; https://jcheminf.biomedcentral.com/articles/10.1186/s13321-016-0158-y
4. For R-NiB Practical: 
      Ahinko et al., 2019; Int J Mol Sci; 20(11):2779; 
      doi: 10.3390/ijms20112779; https://www.mdpi.com/1422-0067/20/11/2779 
5. For R-NiB Book Chapter:
      Pentikäinen & Postila, 2021; Methods Mol Biol; 2266:141-154.
      doi: 10.1007/978-1-0716-1209-5_8; https://link.springer.com/protocol/10.1007%2F978-1-0716-1209-5_8 
