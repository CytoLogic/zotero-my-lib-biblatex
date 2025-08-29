#!/usr/bin/env bash

# Copyright (C) 2025 Jordan Vieler
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

set -euo pipefail
IFS=$'\n\t'

# script options boilerplate
HELP_MSG="
Usage: zotero-my-lib-biblatex.sh [options]

Utilizes zotero web API v3 to export entire contents of \"My Library\" in biblatex format.
Local Zotero application must be running and listening on port 23119.

Options
  -o	Write the export to a given location, in CWD, specified by argument.
	If file already exists, it will be backed up first to a file with name suffixed by \".backup\".
	(default: stdout)

  -h	Display this help message.
"
# Default values
OUTPUT_FILE='/dev/stdout'
while getopts "o:h" OPT; do
    case $OPT in
	o)
	    OUTPUT_FILE=$OPTARG
	    ;;
	h)
	    echo "$HELP_MSG"
	    exit 0
	    ;;

	# handle invalid option 
	\?);;

	# handle missing argument
	:);;
  esac
done
# shift positional parameters
shift $((OPTIND-1))
# script can now reference $1..$n normally

# Make get request to local zotero instance
# write out response body to $OUTPUT_FILE
# capture the Link header
declare LINK_HEADER
get_zotero_biblatex_items(){
    local url=$1
    local write_out='%header{Link}'
    declare response
    response=$(curl -s -w "$write_out" -H 'Zotero-API-Version: 3' "$url")
    # store the response link header
    LINK_HEADER=$(echo "$response" | tail -1)
    # write out the response body
    echo "$response" | head -n -1 | sed '/^[[:space:]]*$/d' >> "$OUTPUT_FILE"
    # echo "$LINK_HEADER"
}

# Parse an HTTP Response Link header into associative array LINK_MAP
declare -A LINK_MAP=()
parse_link_header() {
    # empty the link map
    LINK_MAP=()
    local link_header=$1
    # set IFS (locally scoped) to match format <url>; rel="id"
    local IFS=,
    local part key url
    for part in $link_header; do
	# get the id section of part
	key=$(echo "$part" | sed -E -e 's/.*; rel=//' | tr -d '"')
	# get the url section of part
	url=$(echo "$part" | sed -E -e 's/; rel=.*//' | tr -d ' <>')
	LINK_MAP["$key"]="$url"
    done
}

# backup and rm old output file if it exists
if [[ -f "$OUTPUT_FILE" ]]; then
    mv "$OUTPUT_FILE" "$OUTPUT_FILE.backup"
fi


# starting url for request
# local zotero listens on port 23119 by default
URL='http://localhost:23119/api/users/0/items?format=biblatex&sort=title&limit=25'
get_zotero_biblatex_items "$URL"
parse_link_header "$LINK_HEADER"

# pagination
# continue making requests while we receive a "next" link
while [[ -v LINK_MAP['next'] ]]; do
    URL="${LINK_MAP['next']}"
    get_zotero_biblatex_items "$URL"
    parse_link_header "$LINK_HEADER"
done 

exit 0
