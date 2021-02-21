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
	if [[ "$1" =~ ^https://www.youtube.com/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "{\"videoId\":\"[a-zA-Z0-9_-]{11}\",.*?\"text\":\".*?[^\\\\]\"" | cut -b 13- | uniq -w 11)
		#includes the name of the video and the id
		ID=$(echo "$DATA_RAW" | cut -b 1-11)
		TITLE=$(echo "$DATA_RAW" | grep -Po "((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\1$" | cut -b 2- | sed 's/.$//')
		#https://www.metaltoad.com/blog/regex-quoted-string-escapable-quotes
	elif [[ "$1" =~ ^https://www.youtube.com/watch\?v=[a-zA-Z0-9_-]{11}/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "\"simpleText\":((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\1},\"shortBylineText\":.*?\"videoId\":\"[a-zA-Z0-9_-]{11}\"")
		#includes the name of the video and the id
		ID=$(echo "$DATA_RAW" | grep -Po "\"videoId\":\"[a-zA-Z0-9_-]{11}\"" | cut -b 12-22)
		TITLE=$(echo "$DATA_RAW" | grep -Po "^\"simpleText\":((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\1" | cut -b 15- | sed 's/.$//');
	else
		echo "Didn't match"
	fi
	#This could probably be done with a case statement but the second regex would be massive.

	paste <(echo "$ID") <(echo "$TITLE")
}
#getData takes in a youtube link as an input and outputs all the related videos (or front page videos in the case of https://www.youtube.com/) in this form:
#[11 characters for the id of the video]	[the title of the video]
#[11 characters for the next video id  ]	[the title of the next video]
#...

viewVideo() {
	vlc "$1"
}

URL="N/A"
VIDEOS="N/A"
while :
do
	echo "Enter in the next action (? for help)"
	read ACTION

	case "$ACTION" in
		\?)
			echo "Commands:"
			echo "?     Show this screen"
			echo "h     Go to the youtube homepage"
			echo "u     Select a video to view based on url"
			echo "/     Search on youtube"
			echo "d     Display the current URL and suggested videos"
			echo "p     Play the current video"
			echo "q     Quit the program"
			;;
		h)
			URL="https://www.youtube.com/"
			VIDEOS=$(getData "$URL")
			;;
		u)
			echo "Enter in the youtube video to go to"
			read URL
			VIDEOS=$(getData "$URL")
			;;

		d)
			echo "You are watching $URL"
			echo "Suggested videos:"
			echo "$VIDEOS" | awk '{printf("%d	%s\n", NR, $0)}'
			;;
		p)
			viewVideo "$URL"
			;;
		q)
			break
			;;
		*)
			echo "Invalid command."
			;;
	esac
done
