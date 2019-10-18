#!/bin/bash
shopt -s extglob
#
# BruteNiB (Brute Force Negative Image-Based Rescoring)
#
# Description: The "BruteNiB script evaluates the impact of each cavity point (or atom) in a cavity-based negative image or
# NIB model for the negative image-based rescoring (R-NiB) of explicit PLANTS docking poses. If the removal of any
# of the points/atoms improves the R-NiB yield, the corresponding line is removed from the NIB model permanently. The iterative
# remove & evaluate process with the outputted model is done to each point/atom using a systematic brute force approach.

# USAGE: ./brutenib.sh input_nib.mol2 ligand_file.mol2 [slurm|number [EF|BRn]]
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

GENERATION=0
VICTIM=1
WDIR=gen${GENERATION}
MOF=model-g${GENERATION}-${VICTIM}.mol2
MOT=model-g${GENERATION}-${VICTIM}-rescore
WINNER=${WDIR}/${MOF}
SCORE=$(get_score "${4}" ${VICTIM})

# Test max 50 generations
while [[ ${GENERATION} -lt 50 ]]
do
    BEST=${SCORE}
    CAND=${WINNER}
    GENERATION=$[GENERATION + 1]
    WDIR=gen${GENERATION}
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
    for VICTIM in model-g*.mol2
    do
	../run_rocker.sh ${VICTIM%.mol2}-rescore "${4}" &
	NPROC=$[NPROC + 1]
	if [[ "$NPROC" -ge ${3:-4} ]]; then
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
	EF=$(get_score "${4}" ${VICTIM})
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
	ln -s ${CAND} .
	WINP=${CAND#*/}
	rm ${WDIR}/!(${WINP%.mol2})-rescore.txt  # Remove all but winner's shaep table
    else
	# No improvement
	echo "Final: ${WINNER}"
	exit 0
    fi
done


