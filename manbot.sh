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
	names=$(echo "$1" | grep -Eo '([[:alnum:]\-_:]+\([[:digit:]][[:lower:]]?\))')
	out=
	for fullname in $names
	do
		name=${fullname%\(*\)}
		section=$(echo $fullname | grep -Eo '\([[:digit:]][[:lower:]]?\)')
		section=${section#\(}
		section=${section%\)}

		if (whatis -s $section $name > /dev/null)
		then
			out="${out:+${out}; }$name($section) $(whatis -s $section $name 2>&1 | grep "^$name[(, ]" | grep -o '\- .*$') - https://man.openbsd.org/$name.$section"
		else
			out="${out:+${out}; }no such thing as $name($section)"
		fi
	done
	writeout "$out"
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
	set -- $(printf "%s" "${LINE}" | tr -cd '[:alnum:]()\-_: ')
	set +f

	# Parse input
	allargs="${*}"

	DATE="${1}"
	TIME="${2}"
	NICK="${3}"
	MSG="${allargs##"${DATE} ${TIME} ${NICK}"}"

	# if message contains a manpage reference and is not from the bot
	if [ "${NICK}" != "${MYNICK}" ] && echo ${MSG} | grep -Eq '([[:alnum:]\-_:]+\([0-9][[:lower:]]?\))'
	then                              # quotes around ${MSG} break it
		printman "${MSG}"
		sleep 5
	fi

done
