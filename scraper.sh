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

ID_LENGTH=11
#Youtube ids are 11 characters that are capital and lowercase letters, letters, hyphens and underscores.

HTML=""

getData() {
	ID="No IDs found"
	TITLE="No titles found"
	STRING_REGEX="((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\""
	#https://www.metaltoad.com/blog/regex-quoted-string-escapable-quotes
	if [[ "$1" =~ ^https://www.youtube.com/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "{\"videoId\":$STRING_REGEX,.*?\"text\":$STRING_REGEX" | cut -b 13- | uniq -w 11)
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
		DATA_RAW=$(echo "$HTML" | grep -Po "\"videoId\":$STRING_REGEX,\"thumbnail\".*?\"text\":$STRING_REGEX" | cut -b 12-)
		ID=$(echo "$DATA_RAW" | cut -b 1-11)
		TITLE=$(echo "$DATA_RAW" | grep -Po "$STRING_REGEX$" | cut -b 2- | sed 's/.$//')
	elif [[ $1 =~ ^https://www.youtube.com/playlist ]]
	then
		DATA_RAW=$(youtube-dl --flat-playlist --dump-json $1)
		#This is an extra dependency, but I really have no idea how to not have this. I tried scraping html, but youtube only sends you 100 videos per playlist, and I want the entire thing.
		ID=$(echo "$DATA_RAW" | grep -Po "\"id\": \"[a-zA-Z0-9_-]{11}\"" | cut -b 8-18)
		TITLE=$(echo "$DATA_RAW" | grep -Po "\"title\": $STRING_REGEX" | cut -b 11- | sed "s/.$//")
	fi
	#This could probably be done with a case statement but the second regex would be massive.

	paste <(echo "$ID") <(echo "$TITLE") | uniq
}
#getData reads from HTML and outputs all the related videos (or front page videos in the case of https://www.youtube.com/) in this form:
#[11 characters for the id of the video]	[the title of the video]
#[11 characters for the next video id  ]	[the title of the next video]
#...
#It does read from a global variable, which is awful practice, but I don't know enough bash to not have that without having to recurl getChannelCreator.

getChannelCreator() {
	STRING_REGEX="((?<![\\\\])\")((?:.(?!(?<![\\\\])\1))*.?)\""
	if [[ "$1" =~ ^https://www.youtube.com/watch\?v=[a-zA-Z0-9_-]{11}/?$ ]]
	then
		DATA_RAW=$(echo "$HTML" | grep -Po "\"channelId\":$STRING_REGEX,\"isOwnerViewing\":.*?\"author\":$STRING_REGEX")
		#includes the name of the video and the id
		CHANNEL_NAME=$(echo "$DATA_RAW" | grep -Po "^\"channelId\":$STRING_REGEX" | cut -b 14- | sed "s/.$//")
		CHANNEL_ID=$(echo "$DATA_RAW" | grep -Po "\"author\":$STRING_REGEX$" | cut -b 11- | sed "s/.$//")
		echo "$CHANNEL_NAME$CHANNEL_ID"
	fi
}

viewVideo() {
	mpv "$1"
}

viewThumbnail() {
	feh "https://i.ytimg.com/vi/$1/maxresdefault.jpg" || feh "https://i.ytimg.com/vi/$1/mqdefault.jpg" || feh "https://i.ytimg.com/vi/$1/default.jpg"
}

#Everything above this is where the scraping occurs. As long as these functions work, the entire thing will work. The higher up the function is the more at risk the function is of breaking. To port this to another site, just make sure these functions work.

calc() { awk "BEGIN { print "$*" }"; }
#https://stackoverflow.com/questions/18093871/how-can-i-do-division-with-variables-in-a-linux-shell

displayVideos() {
	VIDEO_LIST=$(echo "$1" | nl -n ln -b a)
	VIDEO_COUNT=$(echo "$VIDEO_LIST" | wc -l)
	if [[ "$VIDEO_COUNT" -gt 30 ]]
	then
		echo "There seem to be more than 30 videos on the list (specifically $VIDEO_COUNT). There are 3 possible things you can do in this situation:"
		echo "(1): Just print out the list like normal"
		echo "(2): Pipe the list through less"
		echo "(3): Print out a 30 video section of the list"
		read OPTION
		case "$OPTION" in
			1)
				echo "$VIDEO_LIST"
				;;
			2)
				echo "$VIDEO_LIST" | less
				;;
			3)
				while :
				do
					PAGE_COUNT=$(calc $VIDEO_COUNT/30 | sed -E "s/\.[0-9]*$//g")
					echo "Enter in the page that you want to go to (0-$(calc $PAGE_COUNT)), q to stop displaying videos."
					read PAGE_SELECTION
					if [[ "$PAGE_SELECTION" == "q" ]]
					then
						break
					else
						BOTTOM_PAGE=$(calc $PAGE_SELECTION*30)
						TOP_PAGE=$(calc $PAGE_SELECTION*30+30)
						echo "$VIDEO_LIST" | awk "NR > $BOTTOM_PAGE && NR <= $TOP_PAGE { print }"
						#https://stackoverflow.com/questions/6491532/how-to-subset-a-file-select-a-numbers-of-rows-or-columns
						#I should really learn awk.
					fi
				done
				;;
		esac
	else
		echo "$VIDEO_LIST"
	fi
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
			echo "c     See information on the channel of the video"
			echo "cc    Go to the channel of the video"
			echo "q     Quit the program"
			;;
		h)
			URL="https://www.youtube.com/"
			HTML=$(curl -s -A "$USER_AGENT" "$URL")
			VIDEOS=$(getData "$URL")
			;;
		u)
			echo "Enter in the youtube video to go to"
			read URL
			HTML=$(curl -s -A "$USER_AGENT" "$URL")
			VIDEOS=$(getData "$URL")
			;;
		s)
			displayVideos "$VIDEOS"
			echo "Enter in the video to go to"
			read LINE
			ID=$(echo "$VIDEOS" | cut -b 1-$ID_LENGTH | sed "${LINE}q;d")
			URL=$(echo "https://www.youtube.com/watch?v=$ID")
			HTML=$(curl -s -A "$USER_AGENT" "$URL")
			VIDEOS=$(getData "$URL")
			;;
		/)
			echo "Enter the search query"
			read QUERY
			QUERY=$(sanitizeSearch "$QUERY")
			URL="https://www.youtube.com/results?search_query=$QUERY"
			HTML=$(curl -s -A "$USER_AGENT" "$URL")
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
			viewThumbnail "$(echo "$VIDEOS" | cut -b 1-$ID_LENGTH | sed "${LINE}q;d")"
			;;
		c)
			CHANNEL_DATA=$(getChannelCreator "$URL")
			CHANNEL_ID=$(echo "$CHANNEL_DATA" | cut -b 1-24)
			CHANNEL_NAME=$(echo "$CHANNEL_DATA" | cut -b 25-)
			echo "Channel id: $CHANNEL_ID"
			echo "Channel name: $CHANNEL_NAME"
			;;
		cc)
			CHANNEL_DATA=$(getChannelCreator "$URL")
			CHANNEL_ID=$(echo "$CHANNEL_DATA" | cut -b 1-24)
			CHANNEL_ID="UU$(echo "$CHANNEL_ID" | cut -b 3-)"
			#The play all feature in youtube generates a playlist with the following format:
			#https:///www.youtube.com/playlist?list=UU{CHANNEL_ID]}
			#where CHANNEL_ID has the first 2 characters, which are always UC, removed. This new CHANNEL_ID is really just the modified channel ID for the link.
			URL="https://www.youtube.com/playlist?list=$CHANNEL_ID"
			VIDEOS=$(getData "$URL")
			;;
		q)
			break
			;;
		*)
			echo "Invalid command. Type ? for help."
			;;
	esac
done
