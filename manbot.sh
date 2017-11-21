#! /bin/sh
#
# An event loop; responds to messages on stdin. Output to stdout.

# Reformat a string (smash all newlines and create new ones at 160 columns) and
# dump it to stdout
writeout ()
{
	printf "%s\n" "${@}" | fold -sw 160 | head -n 2
}

printman ()
{
	names=$(echo "$1" | grep -Eo '([[:alnum:]]+\([0-9][[:lower:]]?\))')
	for fullname in $names
	do
		name=${fullname%\(*\)}
                section=$(echo $fullname | grep -Eo [0-9][[:lower:]]?)

		if (whatis -s $section $name > /dev/null)
		then
			writeout "$(whatis -s $section $name 2>&1 | sed 1q) - https://man.openbsd.org/$name.$section"
		else
			writeout "no such thing as $name($section)"
		fi
	done
}

# Main event loop
while true
do
	# Default values; illegal for real messages because of our sanitization
	DATE="@none@"
	TIME="@none@"
	NICK="@none@"
	MSG="@none@"

	# Get input
	read -r LINE

	# Sanitize input
	set -f
	set -- $(printf "%s" "${LINE}" | tr -cd '[:alnum:]() ')
	set +f

	# Parse input
	allargs="${*}"

	DATE="${1}"
	TIME="${2}"
	NICK="${3}"
	MSG="${allargs##"${DATE} ${TIME} ${NICK}"}"

	# if message contains a manpage reference and is not from the bot
	if [ "${NICK}" != "${MYNICK}" ] && echo ${MSG} | grep -Eq '([[:alnum:]]+\([0-9][[:lower:]]?\))'
	then                              # quotes around ${MSG} break it
		printman "${MSG}"
	fi

done
