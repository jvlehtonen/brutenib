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
    echo "-a REGEXP,           Sets ACTIVENAME for rocker.  Optional."
    echo "--espweight number,  Shaep espweight.  Optional.  Defaults to 0.5."
    echo "-h|--help,           This text"
    exit 1
}

function get_score ()
{
    # args: scoremethod modelnumber wdir
    # echo "#${3}/model-g${GENERATION}-${2}-rescore_enrich.txt#" 1>&2
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

export BRUTEBIN=$(dirname $(realpath $0))

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=$(getopt -o m:l:c:s:p:a:h -l espweight:,help -n 'manytype' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

MODEL=""
LIGANDS=""
CORES="4"
SCORING="AUC"
PREFIX="type"
ACTIVENAME=""
ESPWEIGHT="0.5"
while true ; do
        case "$1" in
                -l) LIGANDS="$2" ; shift 2 ;;
                -m) MODEL="$2"   ; shift 2 ;;
                -p) PREFIX="$2"  ; shift 2 ;;
                -s) SCORING="$2" ; shift 2 ;;
                -c) CORES="$2"   ; shift 2 ;;
                -a) ACTIVENAME="$2" ; shift 2 ; export ACTIVENAME ;;
                --espweight) ESPWEIGHT="$2" ; shift 2 ;;
                -h|--help) usage_and_exit ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

# Verify that necessary programs are available
if [[ ! -e "${ROCKER:=$(which rocker 2>/dev/null)}" ]]
then
    echo "Command 'rocker' not found!"
    exit 1
fi

if [[ ! -e "${SHAEP:=$(which shaep 2>/dev/null)}" ]]
then
    echo "Command 'shaep' not found!"
    exit 1
fi
export ROCKER SHAEP

# Must have model and ligand files
[[ -n "${MODEL}" && -n "${LIGANDS}" ]] || usage_and_exit

[[ -f part1.mol2 ]] || ${BRUTEBIN}/mol2split "${LIGANDS}" ${CHUNK}

# Ensure that we have initial model and its score
[[ -f ${PREFIX}0/model-g0-1-rescore_enrich.txt ]] || ${BRUTEBIN}/oneshot.sh -m ${MODEL} -l ${LIGANDS} -s ${SCORING} -p ${PREFIX}

NIB=${MODEL}

GENERATION=0
VICTIM=1
MOF=model-g${GENERATION}-${VICTIM}.mol2
WINNER=${PREFIX}0/${MOF}
SCORE=$(get_score "${SCORING}" ${VICTIM} ${PREFIX}0)

ATOMS="CNOH"

GENERATION=1
BEST=${SCORE}
WDIR=${PREFIX}${GENERATION}
mkdir ${WDIR}
HEADER=$(grep -n ATOM "${NIB}" | cut -d: -f1)
NUM=$(tail -n +$((1 + ${HEADER})) "${NIB}" | grep -c -v "^$")
[[ "$NUM" -lt 2 ]] && exit 0

# Prepare pockets
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    MOF=model-g${GENERATION}-${VICTIM}
    ln -sr "${NIB}" ${WDIR}/${MOF}-0.mol2
    P=0
    for (( T=1; T<${#ATOMS}; ++T )); do
	sed "${HEADER} q;" "${NIB}" > ${WDIR}/${MOF}-${T}.mol2
	tail -n +$((1 + ${HEADER})) ${WDIR}/${MOF}-${P}.mol2 | sed "${VICTIM} y/CNOH/NOHC/" >> ${WDIR}/${MOF}-${T}.mol2
	P=$((P + 1))
    done
done
rm ${WDIR}/model-g${GENERATION}-*-0.mol2

# Rescore pockets
pushd ${WDIR}
NPROC=0
for PLIC in ../part*.mol2
do
    for VICTIM in model-g*.mol2
    do
	echo "###${BRUTEBIN}/nibscore.sh ${VICTIM} "${PLIC}" ${ESPWEIGHT}###"
	${BRUTEBIN}/nibscore.sh ${VICTIM} "${PLIC}" ${ESPWEIGHT} 2> /dev/null &
	NPROC=$((NPROC + 1))
	if [[ "$NPROC" -ge ${CORES} ]]; then
	    wait
	    NPROC=0
	fi
    done
done
wait

NPROC=0
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    for (( T=1; T<${#ATOMS}; ++T )); do
	${BRUTEBIN}/run_rocker.sh model-g${GENERATION}-${VICTIM}-${T}-rescore "${SCORING}" &
	NPROC=$((NPROC + 1))
	if [[ "$NPROC" -ge ${CORES} ]]; then
	    wait
	    NPROC=0
	fi
    done
done
wait
popd

BEST=${SCORE}
for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
do
    for (( T=1; T<${#ATOMS}; ++T )); do
	EF=$(get_score "${SCORING}" "${VICTIM}-${T}" ${WDIR})
	if [[ 1 = $(echo $EF'>'$BEST | bc -l) ]] ; then
	    BEST=$EF
	    BV=${VICTIM}
	    BT=${T}
	fi
    done
done
if [[ 1 = $(echo $BEST'>'$SCORE | bc -l) ]] ; then
    echo "Best g${GENERATION}-${BV}-${BT}"
    cat ${WDIR}/model-g${GENERATION}-${BV}-${BT}-rescore_enrich.txt
    ln -s ${WDIR}/model-g${GENERATION}-${BV}-${BT}.mol2 ${PREFIX}.mol2
else
    echo "No improvement"
    exit 2
fi

