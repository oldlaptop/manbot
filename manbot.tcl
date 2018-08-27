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
		puts $nickdb
	} else {
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
			writeout "$out - https://man.openbsd.org/$name.$section" $nick
		}
		
	}
}