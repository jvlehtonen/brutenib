#!/bin/bash
shopt -s extglob
#
# Brutetype
#
# Description: Generates a model that has modified atom types.
# Program generates two new models per atom in input_nib.mol2.
# Same position will have C, N, and O in related models.
# There is only one atom changed in each new model.
# The scores of models that differ in same position are compared,
# and atom type of best is copied to a final model.
#
# Requires that brutenib.sh has been run; will read score of the
# input model from directory gen0.
#
# Final model (and score) will be written to directory type1.
#
# USAGE: ./brutetype.sh input_nib.mol2 ligand_file.mol2 [slurm|number [EF|BRn]]
# Input #1 A cavity-based NIB model from PANTHER (in MOL2 format).
# Input #2 A ligand file with multiple docking poses for actives (LIG) and inactives from PLANTS (in MOL2 format).
# Input #3 Either word "slurm" or the number of processors to be used in the ShaEP-based NIB rescoring.  Optional.  Defaults to 4.
# Input #4 Used scoring method. Optional.  Defaults to AUC. 'EF' or 'BR'. BR can have a number. Anything else selects AUC.

# External software requirements: ROCKER and ShaEP installed in the path.

function get_score ()
{
    case "${1}" in
	'EF')
	    # echo "Rank by EFd 1"
	    sed -n "s/EF_1.0.*= //p" ${WDIR}/model-g${GENERATION}-${2}-rescore_enrich.txt ;;
	BR*)
	    # echo "Rank by BR ${BRA}"
	    sed -n "s/BEDROC.*= //p" ${WDIR}/model-g${GENERATION}-${2}-rescore_enrich.txt ;;
	*)
	    # echo "Rank by AUC"
	    sed -n "/AUC/ {s/AUC=//; s/+-.*//; p}" ${WDIR}/model-g${GENERATION}-${2}-rescore_enrich.txt ;;
    esac
}

[[ $# -lt 2 ]] && exit 1

# Ensure that we have initial model and its score
[[ -f gen0/model-g0-1-rescore_enrich.txt ]] || ./oneshot.sh "$@"

NIB=$1

GENERATION=0
WDIR=gen${GENERATION}
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
WINNER=${WDIR}/${MOF}
SCORE=$(get_score "${4}" ${VICTIM})
echo "The best pocket of generation ${GENERATION} was ${WINNER}"
cat ${WINNER%.mol2}-rescore_enrich.txt


BEST=${SCORE}
WDIR=type${GENERATION}
mkdir ${WDIR}
HEADER=$(grep -n ATOM "${NIB}" | cut -d: -f1)
NUM=$(tail -n +$[1 + ${HEADER}] "${NIB}" | grep -c -v "^$")
[[ "$NUM" -lt 2 ]] && exit 0

# Prepare pockets
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    MOF=model-g${GENERATION}-${VICTIM}.mol2
    sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOF}
    tail -n +$[1 + ${HEADER}] "${NIB}" | sed "${VICTIM} y/CNO/NOC/" >> ${WDIR}/${MOF}

    THIRD=$[${NUM} + ${VICTIM}]
    MOG=model-g${GENERATION}-${THIRD}.mol2
    sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOG}
    tail -n +$[1 + ${HEADER}] ${WDIR}/${MOF} | sed "${VICTIM} y/CNO/NOC/" >> ${WDIR}/${MOG}
done

# Rescore pockets
pushd ${WDIR}
NPROC=0
for PLIC in ../part*.mol2
do
    for VICTIM in model-g*.mol2
    do
	../nibscore.sh ${VICTIM} "${PLIC}" &
	NPROC=$[NPROC + 1]
	if [[ "$NPROC" -ge ${3:-4} ]]; then
	    wait
	    NPROC=0
	fi
    done
done
wait

NPROC=0
for (( VICTIM=1; VICTIM<=$[${NUM} + ${NUM}]; ++VICTIM ))
do
    ../run_rocker.sh model-g${GENERATION}-${VICTIM}-rescore "${4}" &
    NPROC=$[NPROC + 1]
    if [[ "$NPROC" -ge ${3:-4} ]]; then
	wait
	NPROC=0
    fi
done
wait
popd

WWDIR=type1
mkdir ${WWDIR}
sed "${HEADER} q;" "${NIB}" > "${WWDIR}/model-g1-1.mol2"
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    EF=$(get_score "${4}" "${VICTIM}")
    THIRD=$[${NUM} + ${VICTIM}]
    EG=$(get_score "${4}" ${THIRD})

    if [[ 1 = $(echo $EF'>'$BEST | bc -l) ]] ; then
	if [[ 1 = $(echo $EG'>'$EF | bc -l) ]] ; then
	    sed -n "$[${VICTIM} + ${HEADER}] p" "${WDIR}/model-g${GENERATION}-${THIRD}.mol2" >> "${WWDIR}/model-g1-1.mol2"
	else
	    sed -n "$[${VICTIM} + ${HEADER}] p" "${WDIR}/model-g${GENERATION}-${VICTIM}.mol2" >> "${WWDIR}/model-g1-1.mol2"
	fi
    elif [[ 1 = $(echo $EG'>'$BEST | bc -l) ]] ; then
	sed -n "$[${VICTIM} + ${HEADER}] p" "${WDIR}/model-g${GENERATION}-${THIRD}.mol2" >> "${WWDIR}/model-g1-1.mol2"
    else
	sed -n "$[${VICTIM} + ${HEADER}] p" "${NIB}" >> "${WWDIR}/model-g1-1.mol2"
    fi
done

GENERATION=1
pushd ${WWDIR}
for PLIC in ../part*.mol2
do
    for VICTIM in model-g*.mol2
    do
	../nibscore.sh ${VICTIM} "${PLIC}"
    done
done

VICTIM=1
../run_rocker.sh model-g${GENERATION}-${VICTIM}-rescore "${4}"
popd
cat ${WWDIR}/model-g1-1-rescore_enrich.txt
