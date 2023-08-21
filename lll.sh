#!/bin/bash
set -e

gcd() {
	# Usage: gcd a b
	# Prints gcd(a,b) to stdout
	if (("$1" < 0)) ; then
		gcd $((-1 * "$1")) "$2"
	elif (("$2" > "$1")) ; then
		gcd "$2" "$1"
	elif (("$2" == 0)) ; then
		printf '%d\n' "$1"
	else
		gcd "$2" $(( $1 % $2 ))
	fi
}

##### Integer vector (ivec) functions #####
#
#  ivecs are integers separated by commas
#  e.g. "1,2,3,4,5" represents the vector [1,2,3,4,5].

ivec_dot() {
	# Usage: dot ivec1 ivec2 
	# Takes a dot product of integer vectors (ivecs)
	# ivecs should be integers separated by commas
	# e.g dot "1,2,3" "4,5,6" outputs 32
	# Prints integer result to stdout
	local accum=0 i=0 A B
	IFS=',' read -ra A <<-EOF
		$1
	EOF
	IFS=',' read -ra B <<-EOF
		$2
	EOF
	(( "${#A[*]}" == "${#B[*]}" )) || {
		echo "ERROR: ivec_dot called on vectors of different length"
		echo "offending vectors:"
		printf '%s\n' "$1"
		printf '%s\n' "$2"
		exit 1
	} 1>&2
	i=0
	while (( i < "${#A[*]}" )); do
		accum=$(( accum + (A[i] * B[i]) ))
		(( ++i ))
	done
	printf '%d\n' "$accum"
}

ivec_scale() {
	# Usage: ivec_scale c ivec
	# Computes c * ivec (where c is an integer)
	# Prints ivec result to stdout
	local A i
	IFS=',' read -ra A <<-EOF
		$2
	EOF
	printf "%d" "$(( A[0] * $1 ))" # c * ivec[0]
	i=0
	while (( ++i < "${#A[*]}" )); do # start from 1
		printf ",%d" "$(( A[i] * $1 ))" # c * ivec[i]
	done
	echo
}

ivec_add() {
	# Usage: ivec_add ivec1 ivec2
	# Performs vector+vector addition of two integer vectors
	# Prints ivec result to stdout
	local A B i
	IFS=',' read -ra A <<-EOF
		$1
	EOF
	IFS=',' read -ra B <<-EOF
		$2
	EOF
	if [ "${#A[*]}" -ne "${#B[*]}" ]; then
		echo "ivec_add: vectors must have same dimension" 1>&2
		return 1
	fi
	i=0
	printf "%d" "$(( A[0] + B[0] ))"
	while (( ++i < "${#A[*]}" )) ; do # start from i=1
		printf ",%d" "$(( A[i] + B[i] ))"
	done
}

ivec_sub() {
	# Usage: ivec_sub ivec1 ivec2
	# Performs vector-vector subtraction of two integer vectors
	# Prints ivec result to stdout
	local A B i
	IFS=',' read -ra A <<-EOF
		$1
	EOF
	IFS=',' read -ra B <<-EOF
		$2
	EOF
	if [ "${#A[*]}" -ne "${#B[*]}" ]; then
		echo "ivec_sub: vectors must have same dimension" 1>&2
		return 1
	fi
	i=0
	printf "%d" "$(( A[0] - B[0] ))"
	while (( ++i < "${#A[*]}" )) ; do # start from i=1
		printf ",%d" "$(( A[i] - B[i] ))"
	done
}

##### Functions for working with rationals
#
#  TODO: BigRational (BigRat) support
#  "Rationals of unusual sizes? I don't believe they exiiiiiiist!"

rfrac() {
	# Usage: rfrac denom num
	# Reduces the fraction
	# Prints output to stdout as "denom num"
	local common denom num
	common="$(gcd "$1" "$2")"
	denom="$(( $1 / common ))"
	num="$(( $2 / common ))"
	printf "%d %d\n" "$denom" "$num"
}

roundnearest() {
	# Usage: roundnearest denom num
	# rounds to nearest, breaking ties by rounding toward +Infinity
	# (division in arithmetic expansion will round toward zero, but we want to round consistently in one direction)
	# fails due to overflow if abs(num) > 2^62 or so
	local num="$2" denom="$1"
	if (( (num < 0) && (-num != num) )); then
		# ensure num is nonnegative
		roundnearest "$((-denom))" "$((-num))"
		return
	fi
	if (( (denom > 0) )); then
		# floor( n/d + 1/2 )
		printf "%d\n" "$(( (2 * num + denom) / (2 * denom) ))"
	else
		# ceil(n/d), or ceil(n/d)-1 if (2(n%d) strictly > -d)
		printf "%d\n" "$(( (2 * (num % denom) > -denom)  ?  (num / denom) - 1 : (num / denom) ))"
	fi
}

##### BigRat(ionals)
# "Rationals of unusual size?
#    I don't think they exis--"
# 
#     n   r+   _,-===-,_
#   __L\_/@|-+"         "+,
#  /    o  /               \
# 0                        k_,-==-,_   
#  \vv--_                   --'""--,"\
#        \                 /         ||
#        / ___    _,=,_   /  _,,,___//
#      <<,/   <<,/   <,,,"  "=""==--"
#
## TODO: implement

##### Rational vector (rvec) functions #####
#
#  rvecs are integers separated by colons
#  The first integer is the denominator for the entire vector.
#  The rest are the numerators.
#  e.g. "10:9:8:7" represents the vector [0.9, 0.8, 0.7].
#  We do this instead of having separate denominators for each component
#  because "it seemed like a good idea at the time."

ivec_to_rvec() {
	# Usage: ivec_to_rvec ivec
	# Convert an integer vector to a rational vector
	# Prints rvec result to stdout
	# Example: ivec_to_ratvec 1,2,3
	# Example output: 1:1:2:3
	local A
	IFS=',' read -ra A <<-EOF
		$1
	EOF
	(IFS=":" ; printf "1:%s\n" "${A[*]}")
}

rvec_reduce() {
	# Usage: rvec_reduce rvec
	# Reduce fraction in a rational vector (rvec)
	# Prints rvec result to stdout
	# e.g., rvec_reduce 100:20:50:70
	# would output 10:2:5:7
	# meaning [.2, .5, .7]
	local accum A i
	IFS=':' read -ra A <<-EOF
		$1
	EOF
	# Step 1: take gcd of everything
	accum="${A[0]}"
	i=0
	while (( ++i < "${#A[*]}" )); do # start from 1
		accum="$( gcd "${A[$i]}" "$accum" )"
	done
	# Step 2: divide everything by gcd
	i=0
	printf "%d" "$(( A[i] / accum ))"
	while (( ++i < "${#A[*]}" )); do # start from 1
		printf ":%d" "$(( A[i] / accum ))"
	done
	echo
}

rvec_scale() {
	# Usage: rvec_scale denom num rvec
	# Computes (num/denom) * rvec
	# rvecs should be integers separated by colons, where the first is the denominator
	# Prints rvec result to stdout
	local A i
	IFS=':' read -ra A <<-EOF
		$3
	EOF
	printf "%d" "$(( A[0] * $1 ))" # rvec[0] * denom
	i=0
	while (( ++i < "${#A[*]}" )); do # start from 1
		printf ":%d" "$(( A[i] * $2 ))" # rvec[i] * num
	done
	echo
}

rvec_add() {
	# Usage: rvec_add rvec1 rvec2
	# Performs vector+vector addition of two rational vectors
	# Prints (reduced) rvec result to stdout
	local A B g denom scaleA scaleB AplusB
	IFS=':' read -ra A <<-EOF
		$1
	EOF
	IFS=':' read -ra B <<-EOF
		$2
	EOF
	if [ "${#A[*]}" -ne "${#B[*]}" ]; then
		echo "rvec_add: vectors must have same dimension" 1>&2
		return 1
	fi
	g="$(gcd "${A[0]}" "${B[0]}" )"
	denom="$(( (A[0] * B[0]) / g ))" # denom = lcm(denom1, denom2)
	scaleA="$(( B[0] / g ))"
	scaleB="$(( A[0] / g ))"
	AplusB="$( {
		printf "%d" "$denom"
		i=0
		while (( ++i < "${#A[*]}" )) ; do # start from 1
			printf ":%d" "$(( A[i] * scaleA + B[i] * scaleB ))"
		done
		unset i
	} )"
	rvec_reduce "$AplusB"
}

rvec_sub() {
	# Usage: rvec_sub rvec1 rvec2
	# Performs vector-vector subtraction of two rational vectors
	# Prints (reduced) rvec result to stdout
	local A B g denom scaleA scaleB AminusB
	IFS=':' read -ra A <<-EOF
		$1
	EOF
	IFS=':' read -ra B <<-EOF
		$2
	EOF
	if [ "${#A[*]}" -ne "${#B[*]}" ]; then
		echo "rvec_sub: vectors must have same dimension" 1>&2
		return 1
	fi
	g="$(gcd "${A[0]}" "${B[0]}" )"
	denom="$(( (A[0] * B[0]) / g ))" # denom = lcm(denom1, denom2)
	scaleA="$(( B[0] / g ))"
	scaleB="$(( A[0] / g ))"
	AminusB="$( {
		printf "%d" "$denom"
		i=0
		while (( ++i < "${#A[*]}" )) ; do # start from 1
			printf ":%d" "$(( A[i] * scaleA - B[i] * scaleB ))"
		done
		unset i
	} )"
	rvec_reduce "$AminusB"
}

rvec_dot() {
	# Usage: rvec_dot rvec1 rvec2 
	# Computes dot product of two rational vectors
	# Prints scalar result to stdout as (reduced) "denom num"
	local A B accum i num denom
	IFS=':' read -ra A <<-EOF
		$1
	EOF
	IFS=':' read -ra B <<-EOF
		$2
	EOF
	(( "${#A[*]}" == "${#B[*]}" )) || {
		echo "ERROR: rvec_dot called on vectors of different length"
		echo "offending vectors:"
		printf '%s\n' "$1"
		printf '%s\n' "$2"
		exit 1
	} 1>&2
	i=0
	num=0
	while (( ++i < "${#A[*]}" )); do # start from 1
		num=$(( num + (A[i] * B[i]) ))
	done
	denom="$(( A[0] * B[0] ))"
	rfrac "$denom" "$num"
}

rvec_mu() {
	# Usage: rvec_mu a b
	# Computes <a,b> / <b,b> (where a and b are rvecs)
	# Prints scalar result to stdout as (reduced) "denom num"
	local denom1 num1 denom2 num2
	read -r denom1 num1 <<-EOF
		$( rvec_dot "$1" "$2" )
	EOF
	read -r denom2 num2 <<-EOF
		$( rvec_dot "$2" "$2" )
	EOF
	rfrac "$(( denom1 * num2 ))" "$(( denom2 * num1 ))"
}

rvec_proj() {
	# Usage: rvec_proj a b
	# where a and b are both rvecs
	# Computes the projection of a onto b, i.e., b * mu(a,b)
	# Prints (reduced) rvec result to stdout
	local denom num
	read -r denom num <<-EOF
		$( rvec_mu "$1" "$2" )
	EOF
	rvec_reduce "$( rvec_scale "$denom" "$num" "$2" )"
}

rvec_projout() {
	# Usage: rvec_projout a b
	# where a and b are both rvecs
	# Projects out the b component of a, leaving something orthogonal to b
	# i.e., rvec_projout(a,b) + rvec_proj(a,b) = a
	# Prints (reduced) rvec result to stdout
	rvec_reduce "$( rvec_sub "$1" "$( rvec_proj "$1" "$2" )" )"
}

rvec_iszero() {
	# Returns 0 if vector is zero, nonzero if vector is nonzero
	local i _vec
	IFS=':' read -ra _vec <<-EOF
		$1
	EOF
	i=1
	while (( i < ${#_vec[*]} ))
	do
		if [ "${_vec[$i]}" -ne 0 ]; then
			return 1
		fi
		i="$(( i + 1 ))"
	done
	return 0
}

##### Gram-Schmidt Orthogonalization, Babai's Nearest Plane, etc. #####
#
#  These functions read/write to global array variable Bstar (which consists of rvecs)
#  and in some cases global array variable Basis (which consists of ivecs)

rvec_gs() {
	# Gram-Schmidt orthogonalization
	# Reads basis from stdin as one rvec per line
	# Prints Gram-Schmidt orthogonalization to stdout, one rvec per line
	# Also write Gram-Schmidt orthogonalization to global array variable Bstar
	local tmp
	declare -ag Bstar
	while read -r basisvec
	do
		tmp="$basisvec"
		for bstarvec in "${Bstar[@]}" ; do
			tmp="$( rvec_projout "$tmp" "$bstarvec" )"
		done
		if ! rvec_iszero "$tmp" ; then
			Bstar[${#Bstar[*]}]="$tmp"
			printf "%s\n" "$tmp"
		fi
	done
}

gramschmidt() {
	# Gram-Schmidt where input is ivecs instead of rvecs
	local matrix="$( while read line; do ivec_to_rvec "$line" ; done )"
	rvec_gs <<-EOF
		$matrix
	EOF
}

rvec_projoutall() {
	# Usage: rvec_projoutall rvec l
	# Reads global variable Bstar
	# Projects out the first l rows of Bstar, which are assumed to be mutually orthogonal
	# The result is orthogonal to Bstar[0], ..., Bstar[l-1].
	# If l=0, return rvec unchanged.
	local i=0 x="$1" l="$2" c
	l=$(( l < "${#Bstar[*]}" ? l : "${#Bstar[*]}" ))
	while (( i < l )); do
		c="$( rvec_mu "$x" "${Bstar[$i]}" )" # c of the form "denom num"
		x="$( rvec_sub "$x" "$( rvec_scale $c "${Bstar[$i]}" )" )"
		i="$((i + 1))"
	done
	printf "%s\n" "$x"
}

nearestplane() {
	# Usage: nearestplane target l
	# target: rvec
	# l: int
	# Uses global array variables Basis and Bstar
	# Does Babai's Nearest Plane on target w.r.t. Basis[:l].
	local target="$1" l="$2" i out
	i="$l"
	# loop from l-1 down to 0
	while (( i > 0 )); do
		i="$(( i - 1 ))"
		# c = round(mu(target, Bstar[i]))
		local c="$( roundnearest $(rvec_mu "$target" "${Bstar[$i]}" ) )"
		#printf "%d %d %s %s %s\n" "$i" "$c" "$target" "${Bstar[$i]}" "${Basis[$i]}" 1>&2
		if [ -z "$out" ]; then
			out="$( ivec_scale "$c" "${Basis[$i]}" )"
		else
			out="$( ivec_add "$out" "$(ivec_scale "$c" "${Basis[$i]}" )" )"
		fi
		target="$( rvec_add "$target" "$(ivec_to_rvec "$(ivec_scale "$(( -c ))" "${Basis[$i]}" )" )" )"
	done
	printf "%s\n" "$out"
}

sizereduce() {
	# Inputs:
	#   global variable Basis (array of ivecs)
	#   global variable Bstar (array of rvecs)
	# Modifies Basis in-place; Bstar does not change
	local i=1 tmp
	# Loop from 1 to len(basis) - 1
	while (( i < "${#Basis[*]}" )) ; do
		tmp="$(ivec_to_rvec "${Basis[$i]}")"
		tmp="$(rvec_sub "$tmp" "${Bstar[$i]}")"
			#printf "nearestplane %s %d\n" "$tmp" "$i" 1>&2
		tmp="$(nearestplane "$tmp" "$i")" # tmp is an ivec now
			#printf "nearestplane returned %s\n" "$tmp" 1>&2
			#printf "Basis[%d] - x = %s - %s\n" "$i" "${Basis[$i]}" "$tmp"
		Basis[$i]="$(ivec_sub "${Basis[$i]}" "$tmp")"
			#printf "Basis[%d] is now %s\n" "$i" "${Basis[$i]}" 1>&2
		i=$(( i + 1 ))
	done
}

##### LLL and input/output #####

readmatrix() {
	# Read a matrix as one vector per line, space-separated integers
	# Compute gram-schmidt orthogonalization at the same time
	# Stores output in global variables Basis and Bstar
	# Note: for now, matrix must be square and full-rank
	local j=0 tmp
	unset Basis Bstar
	declare -ag Basis
	declare -ag Bstar
	while read -r -a basisvec
	do
		# basisvec is space separated; we want comma separated
		Basis[$j]="$( (IFS="," ; printf "%s" "${basisvec[*]}") )"
		tmp="1:$( (IFS=":" ; printf "%s" "${basisvec[*]}") )" # rvec
		for bstarvec in "${Bstar[@]}" ; do
			tmp="$( rvec_projout "$tmp" "$bstarvec" )"
		done
		if ! rvec_iszero "$tmp" ; then
			Bstar[${#Bstar[*]}]="$tmp"
			#printf "%s\n" "$tmp"
		else
			printf "Error: Matrix is not full-rank\n" 1>&2
			return 1
		fi
		j=$((j+1))
	done
	unset tmp
}


lll() {
	local tmp i bhat bprimehat LHS_num LHS_denom RHS_num RHS_denom

	# If stdin and stderr are terminals, show a help message.
	if [ -t 0 ] && [ -t 2 ]; then
		echo 'Enter a full-rank integer matrix, one vector per line, as numbers separated by spaces. Press Ctrl-D after the last line.' 1>&2
	fi

	readmatrix # also does gram-schmidt and stores result in Bstar
	echo "Running LLL..." 1>&2
	while true; do
		sizereduce
		for (( i=0 ; i < ${#Basis[*]} ; i++ )); do
				#printf "i %d\n" "$i" 1>&2
			if (( i == ${#Basis[*]} - 1 )); then
					#echo "lovasz satisfied!" 1>&2
				break 2
			fi
			bhat="$( rvec_projoutall "$(ivec_to_rvec "${Basis[i]}")" "$i" )" # project out Bstar[0], ..., Bstar[i-1] from B[i]
			bprimehat="$( rvec_projoutall "$(ivec_to_rvec "${Basis[i+1]}")" "$i" )" # project out Bstar[0], ..., Bstar[i-1] from B[i+1]
			# compare: 3/4 * ||bhat||^2 >? ||bprimehat||^2
			read -r LHS_denom LHS_num <<-EOF
				$(rvec_dot "$bhat" "$bhat")
			EOF
			LHS_denom="$((LHS_denom * 100))"
			LHS_num="$((LHS_num * 99))"
			read -r LHS_denom LHS_num <<-EOF
				$(rfrac "$LHS_denom" "$LHS_num")
			EOF
			read -r RHS_denom RHS_num <<-EOF
				$(rvec_dot "$bprimehat" "$bprimehat")
			EOF
			if (( LHS_num * RHS_denom > RHS_num * LHS_denom )); then
					#printf "swap %d %d\n" "$i" "$((i+1))"
				tmp="${Basis[i]}"
				Basis[i]="${Basis[i+1]}"
				Basis[i+1]="$tmp"
				Bstar[i]="$( rvec_projoutall "$(ivec_to_rvec "${Basis[i]}")" "$i" )" # project out Bstar[0], ..., Bstar[i-1] from B[i]
				Bstar[i+1]="$( rvec_projoutall "$(ivec_to_rvec "${Basis[i+1]}")" "$((i+1))" )" # project out Bstar[0], ..., Bstar[i] from B[i+1]
				break 1
			fi
		done
	done
	# Print output
	for tmp in "${Basis[@]}"; do
		printf "%s\n" "$tmp"
		# NOTE: output separated by commas instead of spaces.
	done
}

lll
