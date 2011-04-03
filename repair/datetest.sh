#!/usr/bin/ksh

currentlocale=${LC_ALL:-${LC_TIME:-$LANG}}

for i in Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec; do
	datumlen=`date --date="$i 1" +'%b'`
	if [ ${#datumlen} -gt 3 ]; then
		echo "Warning: some of the short month names in your locale ($currentlocale)"
		echo "seem to be longer than 3 characters."
		echo "The default config file (possibly at ${PFMRC:-$HOME/.pfm/.pfmrc})"
		echo "does not take this into account."
		echo "Please verify that your file timestamps are not truncated,"
		echo "otherwise please alter the 'columnlayouts' option."
		break
	fi
done
