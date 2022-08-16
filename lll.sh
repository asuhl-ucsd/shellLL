#!/bin/bash
#set -x

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
		gcd "$2" $(( "$1" % "$2" ))
	fi
}

rfrac() {
	# Usage: rfrac denom num
	# Reduces the fraction
	# Prints output to stdout as "denom num"
	_common="$(gcd "$1" "$2")"
	_denom="$(( "$1" / "$_common" ))"
	_num="$(( "$2" / "$_common" ))"
	printf "%d %d\n" "$_denom" "$_num"
	unset _common _denom _num
}

dot() {
	# Usage: dot ivec1 ivec2 
	# ivecs should be integers separated by commas
	# e.g dot "1,2,3" "4,5,6" outputs 32
	# Prints integer result to stdout
	accum=0
	IFS=',' read -ra A <<-EOF
		$1
	EOF
	IFS=',' read -ra B <<-EOF
		$2
	EOF
	(( "${#A[*]}" == "${#B[*]}" )) || {
		echo "ERROR: dot called on vectors of different length"
		echo "offending vectors:"
		printf '%s\n' "$1"
		printf '%s\n' "$2"
		exit 1
	} 1>&2
	i=0
	while (( i < "${#A[*]}" )); do
		accum=$(( accum + (${A[$i]} * ${B[$i]}) ))
		(( ++i ))
	done
	printf '%d\n' "$accum"
	unset A B accum i
}

rfrac_vec() {
	# Usage: rfrac_vec rvec
	# rvecs should be integers separated by colons, where the first is the denominator
	# Prints output to stdout
	# e.g., rfrac_vec 100:20:50:70
	# would output 10:2:5:7
	# meaning [.2, .5, .7]
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
	printf "%d" "$(( "${A[$i]}" / accum ))"
	while (( ++i < "${#A[*]}" )); do # start from 1
		printf ":%d" "$(( "${A[$i]}" / accum ))"
	done
	echo
	unset accum A i
}

ivec_to_rvec() {
	# Usage: ivec_to_ratvec ivec
	# outputs rvec
	# Example: ivec_to_ratvec 1,2,3
	# Example output: 1:1:2:3
	printf "1"
	IFS=',' read -ra A <<-EOF
		$1
	EOF
	#i=0
	#while (( i < "${#A[*]}" )); do 
	#	printf ":%d" "$(( "${A[i]}" ))"
	#	i=$(( i + 1 ))
	#done
	printf ":%d" "${A[@]}"
	echo
	unset A i
}

rvec_scale() {
	# Usage: rvec_scale denom num rvec
	# Computes (num/denom) * rvec
	# rvecs should be integers separated by colons, where the first is the denominator
	# Prints output to stdout
	IFS=':' read -ra A <<-EOF
		$3
	EOF
	printf "%d" "$(( "${A[0]}" * "$1" ))" # rvec[0] * denom
	i=0
	while (( ++i < "${#A[*]}" )); do # start from 1
		printf ":%d" "$(( "${A[$i]}" * "$2" ))" # rvec[i] * num
	done
	echo
	unset A i
}

ivec_scale() {
	# Usage: ivec_scale c ivec
	# Computes c * ivec
	# Prints output to stdout
	IFS=',' read -ra A <<-EOF
		$2
	EOF
	printf "%d" "$(( "${A[0]}" * "$1" ))" # c * ivec[0]
	i=0
	while (( ++i < "${#A[*]}" )); do # start from 1
		printf ",%d" "$(( "${A[$i]}" * "$1" ))" # c * ivec[i]
	done
	echo
	unset A i
}

rvec_add() {
	# Usage: rvec_add rvec1 rvec2
	# Performs vector+vector addition of two rational vectors
	# Prints (reduced) output to stdout
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
	rfrac_vec "$AplusB"
	unset A B g denom scaleA scaleB AplusB
}

ivec_add() {
	# Usage: ivec_add ivec1 ivec2
	# Performs vector+vector addition of two integer vectors
	# Prints (reduced) output to stdout
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
	printf "%d" "$(( "${A[0]}" + "${B[0]}" ))"
	i=0
	while (( ++i < "${#A[*]}" )) ; do # start from 1
		printf ",%d" "$(( A[i] + B[i] ))"
	done
	unset i
	unset A B
}

rvec_sub() {
	# Usage: rvec_sub rvec1 rvec2
	# Performs vector-vector subtraction of two rational vectors
	# Prints (reduced) output to stdout
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
	AminusB="$( {
		printf "%d" "$denom"
		i=0
		while (( ++i < "${#A[*]}" )) ; do # start from 1
			printf ":%d" "$(( A[i] * scaleA - B[i] * scaleB ))"
		done
		unset i
	} )"
	rfrac_vec "$AminusB"
	unset A B g denom scaleA scaleB AminusB
}

rvec_dot() {
	# Usage: rvec_dot rvec1 rvec2 
	# rvecs should be integers separated by colons, where the first is the denominator
	# Prints dot product to stdout as (reduced) "denom num"
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
		num=$(( num + (${A[$i]} * ${B[$i]}) ))
	done
	denom="$(( A[0] * B[0] ))"
	rfrac "$denom" "$num"
	unset A B accum i num denom
}

rvec_mu() {
	# Usage: rvec_mu a b
	# where a and b are both rvecs (integers separated by colons, where the first is the denominator)
	# Computes <a,b> / <b,b>
	# Prints to stdout as (reduced) "denom num"
	read -r denom1 num1 <<-EOF
		$( rvec_dot "$1" "$2" )
	EOF
	read -r denom2 num2 <<-EOF
		$( rvec_dot "$2" "$2" )
	EOF
	rfrac "$(( denom1 * num2 ))" "$(( denom2 * num1 ))"
	unset denom1 num1 denom2 num2
}

rvec_proj() {
	# Usage: rvec_proj a b
	# where a and b are both rvecs (integers separated by colons, first is denominator)
	# Computes the projection of a onto b, i.e., b * mu(a,b)
	# Prints output (as an rvec) to stdout
	read -r denom num <<-EOF
		$( rvec_mu "$1" "$2" )
	EOF
	rfrac_vec "$( rvec_scale "$denom" "$num" "$2" )"
	unset denom num
}

rvec_projout() {
	# Usage: rvec_projout a b
	# where a and b are both rvecs (integers separated by colons, first is denominator)
	# Projects out the b component of a, leaving something orthogonal to b
	# i.e., rvec_projout(a,b) + rvec_proj(a,b) = a
	# Prints output (as an rvec) to stdout
	rfrac_vec "$( rvec_sub "$1" "$( rvec_proj "$1" "$2" )" )"
}

rvec_iszero() {
	# Returns 0 if vector is zero, nonzero if vector is nonzero
	IFS=':' read -ra _vec <<-EOF
		$1
	EOF
	i=1
	while (( i < ${#_vec[*]} ))
	do
		if [ "${_vec[$i]}" -ne 0 ]; then
			unset i _vec
			return 1
		fi
		i="$(( i + 1 ))"
	done
	unset i _vec
	return 0
}

rvec_gs() {
	# Gram-Schmidt orthogonalization
	# Reads basis from stdin as one rvec per line
	# Prints Gram-Schmidt orthogonalization to stdout, one rvec per line
	j=0
	declare -a Bstar
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
	unset tmp
}

gramschmidt() {
	{
	while read line; do
		ivec_to_rvec "$line"
	done
	} | rvec_gs
}

roundnearest() {
	# Usage: roundnearest denom num
	# rounds to nearest, breaking ties by rounding toward +Infinity
	# (division in arithmetic expansion will round toward zero, but we want to round consistently in one direction)
	# fails if abs(num) > 2^62 or so
	__num="$2"
	__denom="$1"
	if (( (__num < 0) && (-__num != __num) )); then
		# ensure num is nonnegative
		roundnearest "$((-__denom))" "$((-__num))"
		return
	fi
	if (( (__denom > 0) )); then
		# floor( n/d + 1/2 )
		printf "%d\n" "$(( (2 * __num + __denom) / (2 * __denom) ))"
	else
		# ceil(n/d), or ceil(n/d)-1 if (2(n%d) strictly > -d)
		# 
		printf "%d\n" "$(( (2 * (__num % __denom) > -__denom)  ?  (__num / __denom) - 1 : (__num / __denom) ))"
	fi
}

rvec_projoutall() {
	# Usage: rvec_projoutall rvec l
	# Reads global variable Bstar
	# Projects out the first l rows of Bstar, which are assumed to be mutually orthogonal
	# The result is orthogonal to Bstar[0], ..., Bstar[l-1].
	# If l=0, return rvec unchanged.
	_i=0
	_x="$2"
	_l=$(( _l < "${#Bstar[*]}" ? _l : "${#Bstar[*]}" ))
	while (( _i < _l )); do
		_c="$( rvec_mu "$_x" "${Bstar[$_i]}" )" # c of the form "denom num"
		_x="$( rvec_sub "$_x" "$( rvec_scale $_c "${Bstar[$_i]}" )" )"
		_i="$((_i + 1))"
	done
	printf "%s\n" "$_x"
	unset _i _x _l _c
}

nearestplane() {
	# Has a bug somewhere :-/
	# Usage: nearestplane target l
	# target: rvec
	# l: int
	# Uses global array variables Basis and Bstar
	# Does Babai's Nearest Plane on target w.r.t. Basis[:l].
	target="$1"
	unset out_np
	l="$2"
	ii="$l"
	# loop from l-1 down to 0
	while (( ii > 0 )); do
		ii="$(( ii - 1 ))"
		# c = round(mu(target, Bstar[i]))
		local c="$( roundnearest $(rvec_mu "$target" "${Bstar[$ii]}" ) )"
		printf "%d %d %s %s %s" "$ii" "$c" "$target" "${Bstar[$ii]}" "${Basis[$ii]}" 1>&2
		if [ -z "$out_np" ]; then
			out_np="$(ivec_scale "$c" "${Basis[$ii]}" )"
		else
			out_np="$( ivec_add "$out_np" "$(ivec_scale "$c" "${Basis[$ii]}" )" )"
		fi
		target="$( rvec_add "$tmp" "$(ivec_to_rvec "$(ivec_scale "$(( -c ))" "${Basis[$ii]}" )" )" )"
	done
	printf "%s\n" "$out_np"
	unset target out_np l ii
}
