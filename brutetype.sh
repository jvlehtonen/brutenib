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
# External software requirements: ROCKER and ShaEP installed in the path.

function usage_and_exit ()
{
    echo "Usage: ./brutetype.sh options"
    echo "Options:"
    echo "-m input_nib.mol2,   A cavity-based NIB model from PANTHER (in MOL2 format)."
    echo "-l ligand_file.mol2, A ligand file with multiple docking poses for actives (LIG)"
    echo "                     and inactives from PLANTS (in MOL2 format)."
    echo "-c number,           The number of processors to be used in the ShaEP-based NIB rescoring"
    echo "                     and ROCKER.  Optional.  Defaults to 4."
    echo "-s scoring,          Used scoring method. Optional. 'EF' or 'BR'.  BR can have a number."
    echo "                     Anything else selects AUC. Defaults to AUC."
    echo "-p prefix,           Prefix for generated directory names.  Optional.  Defaults to 'gen'."
    echo "--espweight number,  Shaep espweight.  Optional.  Defaults to 0.5."
    echo "-h|--help,           This text"
    exit 1
}

function get_score ()
{
# args: scoremethod modelnumber wdir
    case "${1}" in
	'EF')
	    # echo "Rank by EFd 1"
	    sed -n "s/EF_1.0.*= //p" ${3}/model-g${GENERATION}-${2}-rescore_enrich.txt ;;
	BR*)
	    # echo "Rank by BR ${BRA}"
	    sed -n "s/BEDROC.*= //p" ${3}/model-g${GENERATION}-${2}-rescore_enrich.txt ;;
	*)
	    # echo "Rank by AUC"
	    sed -n "/AUC/ {s/AUC=//; s/+-.*//; p}" ${3}/model-g${GENERATION}-${2}-rescore_enrich.txt ;;
    esac
}

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=$(getopt -o m:l:c:s:p:h -l espweight:,help -n 'brutetype' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

MODEL=""
LIGANDS=""
CORES="4"
SCORING="AUC"
PREFIX="gen"
ESPWEIGHT="0.5"
while true ; do
        case "$1" in
                -l) LIGANDS="$2" ; shift 2 ;;
                -m) MODEL="$2"   ; shift 2 ;;
                -p) PREFIX="$2"  ; shift 2 ;;
                -s) SCORING="$2" ; shift 2 ;;
                -c) CORES="$2"   ; shift 2 ;;
                --espweight) ESPWEIGHT="$2" ; shift 2 ;;
                -h|--help) usage_and_exit ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

# Must have model and ligand files
[[ -n "${MODEL}" && -n "${LIGANDS}" ]] || usage_and_exit

# Ensure that we have initial model and its score
[[ -f ${PREFIX}0/model-g0-1-rescore_enrich.txt ]] || ./oneshot.sh -m ${MODEL} -l ${LIGANDS} -s ${SCORING} -p ${PREFIX}

NIB=${MODEL}

GENERATION=0
WDIR=${PREFIX}${GENERATION}
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
WINNER=${WDIR}/${MOF}
SCORE=$(get_score "${SCORING}" ${VICTIM} ${WDIR})
echo "The best pocket of generation ${GENERATION} was ${WINNER}"
cat ${WINNER%.mol2}-rescore_enrich.txt


BEST=${SCORE}
WDIR=type${GENERATION}
mkdir ${WDIR}
HEADER=$(grep -n ATOM "${NIB}" | cut -d: -f1)
NUM=$(tail -n +$((1 + ${HEADER})) "${NIB}" | grep -c -v "^$")
[[ "$NUM" -lt 2 ]] && exit 0

# Prepare pockets
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    MOF=model-g${GENERATION}-${VICTIM}.mol2
    sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOF}
    tail -n +$((1 + ${HEADER})) "${NIB}" | sed "${VICTIM} y/CNO/NOC/" >> ${WDIR}/${MOF}

    THIRD=$((${NUM} + ${VICTIM}))
    MOG=model-g${GENERATION}-${THIRD}.mol2
    sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOG}
    tail -n +$((1 + ${HEADER})) ${WDIR}/${MOF} | sed "${VICTIM} y/CNO/NOC/" >> ${WDIR}/${MOG}
done

# Rescore pockets
pushd ${WDIR}
NPROC=0
for PLIC in ../part*.mol2
do
    for VICTIM in model-g*.mol2
    do
	../nibscore.sh ${VICTIM} "${PLIC}" ${ESPWEIGHT} &
	NPROC=$((NPROC + 1))
	if [[ "$NPROC" -ge ${CORES} ]]; then
	    wait
	    NPROC=0
	fi
    done
done
wait

NPROC=0
for (( VICTIM=1; VICTIM<=$((${NUM} + ${NUM})); ++VICTIM ))
do
    ../run_rocker.sh model-g${GENERATION}-${VICTIM}-rescore "${SCORING}" &
    NPROC=$((NPROC + 1))
    if [[ "$NPROC" -ge ${CORES} ]]; then
	wait
	NPROC=0
    fi
done
wait
popd

PDIR=${WDIR}
PGEN=${GENERATION}
WDIR=type1

mkdir ${WDIR}
sed "${HEADER} q;" "${NIB}" > "${WDIR}/model-g1-1.mol2"
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    EF=$(get_score "${SCORING}" "${VICTIM}" ${PDIR})
    THIRD=$((${NUM} + ${VICTIM}))
    EG=$(get_score "${SCORING}" ${THIRD} ${PDIR})

    if [[ 1 = $(echo $EF'>'$BEST | bc -l) ]] ; then
	if [[ 1 = $(echo $EG'>'$EF | bc -l) ]] ; then
	    sed -n "$((${VICTIM} + ${HEADER})) p" "${PDIR}/model-g${PGEN}-${THIRD}.mol2" >> "${WDIR}/model-g1-1.mol2"
	else
	    sed -n "$((${VICTIM} + ${HEADER})) p" "${PDIR}/model-g${PGEN}-${VICTIM}.mol2" >> "${WDIR}/model-g1-1.mol2"
	fi
    elif [[ 1 = $(echo $EG'>'$BEST | bc -l) ]] ; then
	sed -n "$((${VICTIM} + ${HEADER})) p" "${PDIR}/model-g${PGEN}-${THIRD}.mol2" >> "${WDIR}/model-g1-1.mol2"
    else
	sed -n "$((${VICTIM} + ${HEADER})) p" "${NIB}" >> "${WDIR}/model-g1-1.mol2"
    fi
done

GENERATION=1
pushd ${WDIR}
for PLIC in ../part*.mol2
do
    for VICTIM in model-g*.mol2
    do
	../nibscore.sh ${VICTIM} "${PLIC}" ${ESPWEIGHT}
    done
done

VICTIM=1
../run_rocker.sh model-g${GENERATION}-${VICTIM}-rescore "${SCORING}"
popd
cat ${WDIR}/model-g1-1-rescore_enrich.txt
