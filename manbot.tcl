#! /usr/bin/env tclsh

package require Tcl 8.5

# Passed to whatis -M
set MANPATH "/usr/ports/infrastructure/man:/usr/X11R6/man:/usr/share/man"

# Rate-limiting information. Dict in the form {nick {nmsg lastmsg}}, where nmsg
# is the number of bot-messages the nick has sent during the current
# ratelimiting period, and lastmsg is the time ([clock seconds]) of the last
# bot-message.
set nickdb {}

# The length of a ratelimiting period; if writeout sees that this many seconds
# or more have passed since the last message from a nick, that nick's entry is
# reset.
set TIMEOUT 60

# The number of messages permitted during a ratelimiting period.
set MAXMSG 4

# Time to wait before autorejoining when kicked
set AUTOREJOIN_PERIOD 10

# The "nick" used by ii for system messages; shouldn't change, really...
set SYS_NICK "-!-"

# Sends msg to stdout, reformatted for IRC. If nick is non-empty, invokes rate-
# limiting logic.
proc writeout {msg {nick ""}} {
	# Analogous to POSIX fold(1), returns a string built by inserting a newline
	# into instr every ncol characters.
	proc fold {instr {ncol 160}} {
		set len [string length $instr]
		set lines_needed [expr $len / $ncol]
		set ret ""
		if {$len % $ncol} {
			# Integer division truncated, account for the partial line
			incr lines_needed
		}

		for {set nl 0} {$nl < $lines_needed} {incr nl} {
			set newline [string range $instr [expr $nl * $ncol] [expr ($nl + 1) * $ncol]]
			set ret [string cat $ret $newline "\n"]
		}

		return $ret
	}

	if {$nick != ""} {
		# Print with ratelimiting
		global nickdb
		global TIMEOUT
		global MAXMSG

		set ct [clock seconds]

		if {![dict exists $nickdb $nick]} {
			dict append nickdb $nick [list 0 $ct]
		}

		set nickentry [dict get $nickdb $nick]

		if {$ct - [lindex $nickentry 1] >= $TIMEOUT} {
			# Reset the time and message count
			set nickentry [list 0 $ct]
		}

		if {[lindex $nickentry 0] < $MAXMSG} {
			set nickentry [list [expr [lindex $nickentry 0] + 1] $ct]
			puts -nonewline [fold $msg]
		}

		# Commit any changes to the global ratelimiting db
		dict set nickdb $nick $nickentry
	} else {
		# Print without ratelimiting
		puts -nonewline [fold $msg]
	}
}

proc printman {msg {nick ""}} {
	global MANPATH
	set pages [regexp -inline -all {[[:alnum:]\-_:]+\([[:digit:]][[:lower:]]?\)} $msg]
	foreach page $pages {
		regexp {[[:alnum:]\-_:]+} $page name

		# We are only interested in what matches the subexpression,
		# inside the parens.
		regexp {\(([[:digit:]][[:lower:]]?)\)} $page dummy section

		if {[catch {exec whatis -M $MANPATH -s $section $name} out]} {
			writeout "no such thing as ${name}($section)" $nick
		} else {
			set descr [regexp -inline [string cat $name {[[:alnum:][:blank:][:punct:]]*-}] $out]
			writeout "[lindex $descr 0] https://man.openbsd.org/$name.$section" $nick
		}
		
	}
}

# Boring utility command, surprised it isn't built in
proc sleep {nsec} {
	after [expr $nsec * 1000] set awake 1
	vwait awake
}

puts :)
while {[gets stdin line] >= 0} {
	global AUTOREJOIN_PERIOD
	global SYS_NICK

	# Would rather not bother stripping <> off
	set mynick [string cat "<" $env(MYNICK) ">"]

	# Messages are formatted like so:
	# 2018-06-19 14:50 <oldlaptop> ls(1) man(1) file(1) printf(3) [...]
	# We are mainly interested in the nickname and the actual message for
	# now, but we might as well store the rest of it while we're parsing.
	set enddate [string first " " $line]
	set endmtim [string first " " $line [expr $enddate + 1]]
	set endnick [string first " " $line [expr $endmtim + 1]]
	set date [string range $line 0 [expr $enddate - 1]]
	set mtim [string range $line [expr $enddate + 1] [expr $endmtim - 1]]
	set nick [string range $line [expr $endmtim + 1] [expr $endnick - 1]]
	set msg [string range $line [expr $endnick + 1] end]

	if {$nick != $mynick &&
	    [regexp {[[:alnum:]\-_:]+\([0-9][[:lower:]]?\)} $msg]} {
		printman $msg $nick
	}

	if {$nick == $SYS_NICK && [regexp [string cat {kicked } $mynick] $msg]} {
		# oh no, we've been kicked!
		sleep $AUTOREJOIN_PERIOD
		puts "/j"
	}
}
puts :(
