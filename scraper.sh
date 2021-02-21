# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

#!/bin/bash
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:53.0) Gecko/20100101 Firefox/53.0"

getData() {
	HTML=$(curl -s -A "$USER_AGENT" "$1")
	ID="No IDs found"
	TITLE="No titles found"
	if (echo "$1" | grep -P "^https://www.youtube.com/?$");
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "{\"videoId\":\"[a-zA-Z0-9\-_]{11}\",.*?\"text\":\".*?[^\\\\]\"")
		ID=$(echo "$DATA_RAW" | cut -b 13-23)
		TITLE=$(echo "$DATA_RAW" | grep -Po "((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\1$" | cut -b 2- | sed 's/.$//')
		#https://www.metaltoad.com/blog/regex-quoted-string-escapable-quotes
	elif (echo "$1" | grep -P "^https://www.youtube.com/watch\?v=[a-zA-Z0-9\-_]{11}/?$");
	then
		ID=$(echo "$HTML" | grep -Po "\"videoId\":\"[a-zA-Z0-9\-_]{11}\"" | cut -b 12-22 | uniq | awk "NR > 1")
		TITLE=$(echo "$HTML" | grep -Po ",\"simpleText\":\".*?\"\}" | tail -n +5 | cut -b 16- | sed "s/..$//" | awk "NR % 3 == 1")
	fi
	paste <(echo "$ID") <(echo "$TITLE")
}

#getData "https://www.youtube.com"
getData "https://www.youtube.com/watch?v=KcZn05qxVgg"
