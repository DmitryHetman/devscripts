#!/bin/sh
#
# getbuildlog: download package build logs from Debian auto-builders
#
# Copyright © 2008 Frank S. Thomas <fst@debian.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA

set -e

PROGNAME=`basename $0`

usage() {
    cat <<EOT
Usage: $PROGNAME <package> [<version-pattern>] [<architecture-pattern>]
  Downloads build logs of <package> from Debian auto-builders.
  If <version-pattern> or <architecture-pattern> are given, only build logs
  whose versions and architectures, respectively, matches the given patterns
  are downloaded.
Options:
  -h, --help        Show this help message.
  -V, --version     Show version and copyright information.
Examples:
  # Download amd64 build log for hello version 2.2-1:
  $PROGNAME hello 2\.2-1 amd64

  # Download mips(el) build logs of all glibc versions:
  $PROGNAME glibc "" mips.*

  # Download all build logs of backported wesnoth versions:
  $PROGNAME wesnoth .*bpo.*
EOT
}

version() {
    cat <<EOT
This is $PROGNAME, from the Debian devscripts package, version ###VERSION###
This code is copyright 2008 by Frank S. Thomas, all rights reserved.
This program comes with ABSOLUTELY NO WARRANTY.
You are free to redistribute this code under the terms of the
GNU General Public License, version 2 or later.
EOT
}

[ "$1" = "-h" ] || [ "$1" = "--help" ] && usage && exit 0
[ "$1" = "-V" ] || [ "$1" = "--version" ] && version && exit 0

[ $# -ge 1 ] && [ $# -le 3 ] || { usage && exit 1; }

if [ ! -x "`which wget 2>/dev/null`" ]; then
    echo "$PROGNAME: this program requires the wget package to be installed";
    exit 1
fi

PACKAGE=$1
VERSION=`(test -z "$2" && echo "[:~+.[:alnum:]-]+") || echo "$2"`
ARCH=`(test -z "$3" && echo "[[:alnum:]-]+") || echo "$3"`
ESCAPED_PACKAGE=`echo "$PACKAGE" | sed -e 's/\+/\\\+/g'`

PATTERN="fetch\.(cgi|php)\?&pkg=$ESCAPED_PACKAGE&ver=$VERSION&arch=$ARCH&\
stamp=[[:digit:]]+"

getbuildlog() {
    BASE=$1
    ALL_LOGS=`mktemp`

    wget -q -O $ALL_LOGS "$BASE/build.php?&pkg=$PACKAGE"

    # Put each href in $ALL_LOGS on a separate line so that $PATTERN
    # matches only one href. This is required because grep is greedy.
    sed -i -e "s/href=\"/\nhref=\"/g" $ALL_LOGS
    # Quick-and-dirty unescaping
    sed -i -e "s/%2B/\+/g" -e "s/%3A/:/g" $ALL_LOGS

    for match in `grep -E -o "$PATTERN" $ALL_LOGS`; do
        ver=`echo $match | cut -d'&' -f3 | cut -d'=' -f2`
        arch=`echo $match | cut -d'&' -f4 | cut -d'=' -f2`
	match=`echo $match | sed -e 's/\+/%2B/g'`
        wget -O "${PACKAGE}_${ver}_${arch}.log" "$BASE/$match&file=log"
    done

    rm -f $ALL_LOGS
}

getbuildlog http://buildd.debian.org
getbuildlog http://buildd.debian-ports.org
getbuildlog http://experimental.debian.net