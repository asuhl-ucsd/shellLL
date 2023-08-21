shellLL: LLL, in the shell!
====

The world's first (and hopefully last) pure-bash implementation of the LLL algorithm. Announced as work-in-progress at the Crypto 2022 rump session; version 1.0 released at the Crypto 2023 rump session.

Note: due to numeric overflow, results will likely be wrong if the lattice dimension is much larger than, say, 5, or if the entries are larger than, say, 30. Implementing BigInts / BigRationals is left for future work, feel free to send a patch!

lll.sh is released into the public domain -- everyone is welcome to enjoy the usability, readability, and maintainability of this 500+ line shell script. (But please send me an email if you do, just because I'll be flabbergasted if anyone actually uses this for anything!)

If referencing shellLL in an academic paper for some reason, please cite:
Adam Suhl, "shellLL: the world's first (and hopefully last) pure-bash LLL implementation." Crypto 2022 Rump Session.
