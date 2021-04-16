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

# MIT License
#
# Copyright (c) 2020 Jukka V. Lehtonen (jukka.lehtonen@abo.fi)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

function usage_and_exit ()
{
    echo "brutenib version 2020-02-06"
    echo ""
    echo "Usage: brutenib.sh options"
    echo "Options:"
    echo "-m model,            E.g. cavity-based NIB model from PANTHER (in MOL2 format)."
    echo "-l training-set,     A ligand file with multiple docking poses for actives (LIG)"
    echo "                     and inactives from e.g. PLANTS (in MOL2 format)."
    echo "-c number,           The number of processors to be used in the ShaEP-based NIB rescoring"
    echo "                     and ROCKER.  Optional.  Defaults to 4."
    echo "-s scoring,          Used scoring method. Optional. 'EF' or 'BR'.  BR can have a number."
    echo "                     Anything else selects AUC. Defaults to AUC."
    echo "-p prefix,           Prefix for generated directory names.  Optional.  Defaults to 'gen'."
    echo "-g number,           Maximum iterations.  Optional.  Defaults to 100."
    echo "-a REGEXP,           Sets ACTIVENAME for rocker.  Optional."
    echo "--espweight number,  Shaep espweight.  Optional.  Defaults to 0.5."
    echo "--exclusion arg,     Shaep exclusion.  Optional."
    echo "--chunk number,      Ligand set is split to chunks to avoid memory exhaustion. Ligands per chunk. Optional.  Defaults to 100000."
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

export BRUTEBIN=$(dirname $(realpath $0))

# Note that we use `"$@"' to let each command-line parameter expand to a
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=$(getopt -o m:l:c:s:p:g:a:h -l espweight:,exclusion:,chunk:,help -n 'brutenib' -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

MODEL=""
LIGANDS=""
CORES="4"
SCORING="AUC"
PREFIX="gen"
ITERATIONS="300"
ACTIVENAME=""
ESPWEIGHT="0.5"
EXCLUSION=""
CHUNK=100000
while true ; do
        case "$1" in
                -l) LIGANDS="$2"    ; shift 2 ;;
                -m) MODEL="$2"      ; shift 2 ;;
                -p) PREFIX="$2"     ; shift 2 ;;
                -s) SCORING="$2"    ; shift 2 ;;
                -c) CORES="$2"      ; shift 2 ;;
                -g) ITERATIONS="$2" ; shift 2 ;;
                -a) ACTIVENAME="$2" ; shift 2 ; export ACTIVENAME ;;
                --espweight) ESPWEIGHT="$2" ; shift 2 ;;
                --exclusion) EXCLUSION="$2" ; shift 2 ;;
                --chunk) CHUNK="$2" ; shift 2 ;;
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
	    ${BRUTEBIN}/nibscore.sh ${VICTIM} "${PLIC}" ${ESPWEIGHT} ${EXCLUSION} &
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
	${BRUTEBIN}/run_rocker.sh ${VICTIM%.mol2}-rescore "${SCORING}" &
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
	break
    fi
done

echo "Final: ${WINNER}"
ln -s ${WINNER} ${PREFIX}-final.mol2
rm ./part*.mol2  # Remove split ${LIGANDS}
