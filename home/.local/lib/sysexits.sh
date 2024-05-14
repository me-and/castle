# EX_USAGE: The command was used incorrectly, e.g., with the wrong number of
# arguments, a bad flag, a bad syntax in a parameter, or whatever.
#
# EX_DATAERR: The input data was incorrect in some way.  This should only be
# used for user's data & not system files.
#
# EX_NOINPUT: An input file (not a system file) did not exist or was not
# readable.  This could also include errors like "No message" to a mailer (if
# it cared to catch it).
#
# EX_NOUSER: The user specified did not exist.  This might be used for mail
# addresses or remote logins.
#
# EX_NOHOST: The host specified did not exist.  This is used in mail addresses
# or network requests.
#
# EX_UNAVAILABLE: A service is unavailable.  This can occur if a support
# program or file does not exist.  This can also be used as a catchall message
# when something you wanted to do doesn't work, but you don't know why.
#
# EX_SOFTWARE: An internal software error has been detected.  This should be
# limited to non-operating system related errors as possible.
#
# EX_OSERR: An operating system error has been detected.  This is intended to
# be used for such things as "cannot fork", "cannot create pipe", or the like.
# It includes things like getuid returning a user that does not exist in the
# passwd file.
#
# EX_OSFILE: Some system file (e.g., /etc/passwd, /var/run/utmp, etc.) does not
# exist, cannot be opened, or has some sort of error (e.g., syntax error).
#
# EX_CANTCREAT: A (user specified) output file cannot be created.
#
# EX_IOERR: An error occurred while doing I/O on some file.
#
# EX_TEMPFAIL: temporary failure, indicating something that is not really an
# error.  In sendmail, this means that a mailer (e.g.) could not create a
# connection, and the request should be reattempted later.
#
# EX_PROTOCOL: the remote system returned something that was "not possible"
# during a protocol exchange.
#
# EX_NOPERM: You did not have sufficient permission to perform the operation.
# This is not intended for file system problems, which should use EX_NOINPUT or
# EX_CANTCREAT, but rather for higher level permissions.
#
# EX_CONFIG: Something was found in an unconfigured or misconfigured state.

declare -ir EX_OK=0
declare -ir EX_USAGE=64
declare -ir EX_DATAERR=65
declare -ir EX_NOINPUT=66
declare -ir EX_NOUSER=67
declare -ir EX_NOHOST=68
declare -ir EX_UNAVAILABLE=69
declare -ir EX_SOFTWARE=70
declare -ir EX_OSERR=71
declare -ir EX_OSFILE=72
declare -ir EX_CANTCREAT=73
declare -ir EX_IOERR=74
declare -ir EX_TEMPFAIL=75
declare -ir EX_PROTOCOL=76
declare -ir EX_NOPERM=77
declare -ir EX_CONFIG=78
