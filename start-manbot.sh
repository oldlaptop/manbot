#! /bin/sh
#
# Spawn event loops for each joined IRC channel. TODO: handle spawning ii

IRCDIR="${HOME}/manbot-irc"
SERVER="irc.freenode.net"
CHANNELS="#openbsd-offtopic"
MYNICK="manbot"

export MYNICK

export PREFIX="$(pwd)"

CHILD_PIDS=

# Kill all event loops
die()
{
	for process in ${CHILD_PIDS}
	do
		kill ${process}
	done
}

# Spawn ii
echo ii -s ${SERVER} -n ${MYNICK} -f "Your Friendly OpenBSD Manpage Bot" -i ${IRCDIR} \&
ii -s ${SERVER} -n ${MYNICK} -f "Your Friendly OpenBSD Manpage Bot" -i ${IRCDIR} &
CHILD_PIDS="${CHILD_PIDS} $!"
sleep 10

# Spawn event loops on all channels
for channel in ${CHANNELS}
do
	echo joining $channel
	printf "%s\n" "/j ${channel}" > "${IRCDIR}/${SERVER}/in"
	sleep 5
	echo spawning $channel event loop
	tail -fn1 "${IRCDIR}/${SERVER}/${channel}/out" | sh "${PREFIX}/manbot.sh" > "${IRCDIR}/${SERVER}/${channel}/in" &
	CHILD_PIDS="${CHILD_PIDS} $!"
done


# Idle, waiting to be SIGTERMed
trap die EXIT
wait

# All event loops are dead
printf "%s\n" "$0: all event loops died, terminating"
