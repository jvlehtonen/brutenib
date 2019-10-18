#!/bin/bash
shopt -s extglob
#
# BruteNiB (Brute Force Negative Image-Based Rescoring)
#
# Description: The "BruteNiB script evaluates the impact of each cavity point (or atom) in a cavity-based negative image or
# NIB model for the negative image-based rescoring (R-NiB) of explicit PLANTS docking poses. If the removal of any
# of the points/atoms improves the R-NiB yield, the corresponding line is removed from the NIB model permanently. The iterative
# remove & evaluate process with the outputted model is done to each point/atom using a systematic brute force approach.

# External software requirements: ROCKER and ShaEP installed in the path.

function usage_and_exit ()
{
    echo "Usage: ./brutenib.sh options"
    echo "Options:"
    echo "-m input_nib.mol2,   A cavity-based NIB model from PANTHER (in MOL2 format)."
    echo "-l ligand_file.mol2, A ligand file with multiple docking poses for actives (LIG)"
    echo "                     and inactives from PLANTS (in MOL2 format)."
    echo "-c number,           The number of processors to be used in the ShaEP-based NIB rescoring"
    echo "                     and ROCKER.  Optional.  Defaults to 4."
    echo "-s scoring,          Used scoring method. Optional. 'EF' or 'BR'.  BR can have a number."
    echo "                     Anything else selects AUC. Defaults to AUC."
    echo "-p prefix,           Prefix for generated directory names.  Optional.  Defaults to 'gen'."
    echo "-g number,           Maximum iterations.  Optional.  Defaults to 100."
    echo "--espweight number,  Shaep espweight.  Optional.  Defaults to 0.5."
    echo "-h|--help,           This text."
    exit 1
}

function get_score ()
{
    case "${1}" in
	'EF')
	    # echo "Rank by EFd 1"
	    sed -n "s/EF_1.0.*= //p" ${2} ;;
	BR*)
	    # echo "Rank by BR ${BRA}"
	    sed -n "s/BEDROC.*= //p" ${2} ;;
	*)
	    # echo "Rank by AUC"
	    sed -n "/AUC/ {s/AUC=//; s/+-.*//; p}" ${2} ;;
    esac
}

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=$(getopt -o m:l:c:s:p:g:h -l espweight:,help -n 'brutenib' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

MODEL=""
LIGANDS=""
CORES="4"
SCORING="AUC"
PREFIX="gen"
ITERATIONS="100"
ESPWEIGHT="0.5"
while true ; do
        case "$1" in
                -l) LIGANDS="$2"    ; shift 2 ;;
                -m) MODEL="$2"      ; shift 2 ;;
                -p) PREFIX="$2"     ; shift 2 ;;
                -s) SCORING="$2"    ; shift 2 ;;
                -c) CORES="$2"      ; shift 2 ;;
                -g) ITERATIONS="$2" ; shift 2 ;;
                --espweight) ESPWEIGHT="$2" ; shift 2 ;;
                -h|--help) usage_and_exit ;;
                --) shift ; break ;;
                *) echo "Internal error!" ; exit 1 ;;
        esac
done

# Must have model and ligand files
[[ -n "${MODEL}" && -n "${LIGANDS}" ]] || usage_and_exit

[[ -f part1.mol2 ]] || ./mol2split "${LIGANDS}" 100000

# Ensure that we have initial model and its score
[[ -f ${PREFIX}0/model-g0-1-rescore_enrich.txt ]] || ./oneshot.sh -m ${MODEL} -l ${LIGANDS} -s ${SCORING} -p ${PREFIX}

GENERATION=0
VICTIM=1
WDIR=${PREFIX}${GENERATION}
MOF=model-g${GENERATION}-${VICTIM}.mol2
MOT=model-g${GENERATION}-${VICTIM}-rescore
WINNER=${WDIR}/${MOF}
SCORE=$(get_score "${SCORING}" "${WDIR}/${MOT}_enrich.txt")

# Test max 50 generations
while [[ ${GENERATION} -lt ${ITERATIONS} ]]
do
    BEST=${SCORE}
    CAND=${WINNER}
    GENERATION=$[GENERATION + 1]
    WDIR=${PREFIX}${GENERATION}
    mkdir ${WDIR}
    NIB=${WINNER}
    HEADER=$(grep -n ATOM "${NIB}" | cut -d: -f1)
    NUM=$(tail -n +$[1 + ${HEADER}] "${NIB}" | grep -c -v "^$")
    [[ "$NUM" -lt 2 ]] && exit 0

    NEW=$[NUM - 1]
    # Prepare pockets
    for (( VICTIM=1; VICTIM<=${NUM}; ++VICTIM ))
    do
	[[ -f exclude.lst ]] && grep -q "^${VICTIM}$" exclude.lst && continue
	MOF=model-g${GENERATION}-${VICTIM}.mol2
	sed "${HEADER} q; s/ *${NUM} */ ${NEW}/" "${NIB}" > ${WDIR}/${MOF}
	tail -n +$[1 + ${HEADER}] "${NIB}" | sed "${VICTIM} d" >> ${WDIR}/${MOF}
    done

    # Rescore pockets
    pushd ${WDIR}
    NPROC=0
    for PLIC in ../part*.mol2
    do
	for VICTIM in model-g*.mol2
	do
	    ../nibscore.sh ${VICTIM} "${PLIC}" ${ESPWEIGHT} &
	    NPROC=$[NPROC + 1]
	    if [[ "$NPROC" -ge ${CORES} ]]; then
		wait
		NPROC=0
	    fi
	done
    done
    wait

    NPROC=0
    for VICTIM in model-g*.mol2
    do
	../run_rocker.sh ${VICTIM%.mol2}-rescore "${SCORING}" &
	NPROC=$[NPROC + 1]
	if [[ "$NPROC" -ge ${CORES} ]]; then
	    wait
	    NPROC=0
	fi
    done
    wait
    popd

    # Find best pocket in generation
    CAND=""
    for VICTIM in ${WDIR}/model-g*-rescore_enrich.txt
    do
	EF=$(get_score "${SCORING}" ${VICTIM})
	if [[ 1 = $(echo $EF'>'$BEST | bc -l) ]] ; then
	    BEST=${EF}
	    CAND=${VICTIM%-rescore_enrich.txt}.mol2
	fi
    done

    # Did we beat the previous generation?
    if [[ -n "${CAND}" ]]
    then
	SCORE=${BEST}
	WINNER=${CAND}
	echo "The best pocket of generation ${GENERATION} was ${WINNER}"
	cat ${WINNER%.mol2}-rescore_enrich.txt
	ln -s ${CAND} ${PREFIX}-${CAND#${WDIR}/}
	WINP=${CAND#*/}
	rm ${WDIR}/!(${WINP%.mol2})-rescore.txt  # Remove all but winner's shaep table
    else
	# No improvement
	echo "Final: ${WINNER}"
	exit 0
    fi
done

rm ./part*.mol2  # Remove split ${LIGANDS}
