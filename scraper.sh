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
	STRING_REGEX="((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\""
	#https://www.metaltoad.com/blog/regex-quoted-string-escapable-quotes
	if [[ "$1" =~ ^https://www.youtube.com/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "{\"videoId\":\"[a-zA-Z0-9_-]{11}\",.*?\"text\":\".*?[^\\\\]\"" | cut -b 13- | uniq -w 11)
		#includes the name of the video and the id
		ID=$(echo "$DATA_RAW" | cut -b 1-11)
		TITLE=$(echo "$DATA_RAW" | grep -Po "$STRING_REGEX$" | cut -b 2- | sed 's/.$//')
	elif [[ "$1" =~ ^https://www.youtube.com/watch\?v=[a-zA-Z0-9_-]{11}/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "\"simpleText\":$STRING_REGEX},\"(short|long)BylineText\":.*?\"videoId\":\"[a-zA-Z0-9_-]{11}\"")
		#includes the name of the video and the id
		ID=$(echo "$DATA_RAW" | grep -Po "\"videoId\":\"[a-zA-Z0-9_-]{11}\"" | cut -b 12-22)
		TITLE=$(echo "$DATA_RAW" | grep -Po "^\"simpleText\":$STRING_REGEX" | cut -b 15- | sed 's/.$//');
	elif [[ $1 =~ ^https://www.youtube.com/results\?search_query=.*/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "\"videoId\":\"[a-zA-Z0-9_-]{11}\",\"thumbnail\".*?\"text\":$STRING_REGEX" | cut -b 12-)
		ID=$(echo "$DATA_RAW" | cut -b 1-11)
		TITLE=$(echo "$DATA_RAW" | grep -Po "$STRING_REGEX$" | cut -b 2- | sed 's/.$//')
	fi
	#This could probably be done with a case statement but the second regex would be massive.

	paste <(echo "$ID") <(echo "$TITLE") | uniq
}
#getData takes in a youtube link as an input and outputs all the related videos (or front page videos in the case of https://www.youtube.com/) in this form:
#[11 characters for the id of the video]	[the title of the video]
#[11 characters for the next video id  ]	[the title of the next video]
#...

viewVideo() {
	vlc "$1"
}

viewThumbnail() {
	feh "https://i.ytimg.com/vi/$1/maxresdefault.jpg"
}

#Everything above this is where the scraping occurs. As long as these functions work, the entire thing will work. The higher up the function is the more at risk the function is of breaking.

displayVideos() {
	echo "$1" | nl -n ln -b a
}

sanitizeSearch() {
	echo "$1" | sed "s/ /+/g"
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
			echo "u     Select a video to view based on a url"
			echo "s     Select a video to view based on its index"
			echo "/     Search on youtube"
			echo "d     Display the current URL and suggested videos"
			echo "p     Play the current video"
			echo "vc    View the thumbnail of the current video"
			echo "vs    View the thumbnail of a suggested video"
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
		s)
			displayVideos "$VIDEOS"
			echo "Enter in the video to go to"
			read LINE
			ID=$(echo "$VIDEOS" | cut -b 1-11 | sed "${LINE}q;d")
			URL=$(echo "https://www.youtube.com/watch?v=$ID")
			VIDEOS=$(getData "$URL")
			;;
		/)
			echo "Enter the search query"
			read QUERY
			QUERY=$(sanitizeSearch "$QUERY")
			URL="https://www.youtube.com/results?search_query=$QUERY"
			VIDEOS=$(getData "$URL")
			;;
		d)
			echo "You are on this page: $URL"
			echo "Suggested videos:"
			displayVideos "$VIDEOS"
			;;
		p)
			viewVideo "$URL"
			;;
		vc)
			viewThumbnail "$(echo "$URL" | cut -b 33-)"
			;;
		vs)
			displayVideos "$VIDEOS"
			echo "Enter in the video to view the thumbnail of"
			read LINE
			viewThumbnail "$(echo "$VIDEOS" | cut -b 1-11 | sed "${LINE}q;d")"
			;;
		q)
			break
			;;
		*)
			echo "Invalid command. Type ? for help."
			;;
	esac
done
