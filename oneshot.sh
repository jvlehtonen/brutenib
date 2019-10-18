#!/bin/bash
shopt -s extglob
#
# oneshot: score original model
#
# USAGE: ./oneshot.sh input_nib.mol2 ligand_file.mol2 [slurm|number [EF|BRn]]
# Input #1 A cavity-based NIB model from PANTHER (in MOL2 format).
# Input #2 A ligand file with multiple docking poses for actives (LIG) and inactives from PLANTS (in MOL2 format).
# Input #3 Either word "slurm" or the number of processors to be used in the ShaEP-based NIB rescoring.  Optional.  Defaults to 4.
# Input #4 Used scoring method. Optional.  Defaults to AUC. 'EF' or 'BR'. BR can have a number. Anything else selects AUC.

# External software requirements: ROCKER and ShaEP installed in the path.

[[ $# -lt 2 ]] && exit 1

NIB=$1
WHOLELIC=$2
./mol2split "${WHOLELIC}" 100000

GENERATION=0
WDIR=gen${GENERATION}
mkdir ${WDIR}
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
cp "${NIB}" ${WDIR}/${MOF}
pushd ${WDIR}
for PLIC in ../part*.mol2
do
    ../nibscore.sh ${MOF} "${PLIC}"
done
../run_rocker.sh model-g${GENERATION}-${VICTIM}-rescore "$4"

popd
WINNER=${WDIR}/${MOF}

echo "The best pocket of generation ${GENERATION} was ${WINNER}"
cat ${WINNER%.mol2}-rescore_enrich.txt
ln -s ${WINNER} .
