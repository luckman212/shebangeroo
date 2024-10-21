#!/bin/zsh --no-rcs

_usage() {
	cat <<-EOF
	iterates over a directory (and subdirectories) and tests shebangs it finds for validity
	usage: $1 <path> [regex-search] [max_size]
		- use . or leave blank to default to current dir
		- example of regex search could be: \`python\`
		- max_size will default to 128k unless spefified
	EOF
}

_timestamp() {
	local t=${EPOCHREALTIME/.}
	echo ${t[1,13]}
}

case $1 in
	-h|--help) _usage "${0:t}"; exit;;
esac

zmodload zsh/datetime

SEARCH_PATH=${1:-$PWD}
SEARCH_RE=${2:-}
MAX_SIZE=${3:-512k}
ERR_LOG="/tmp/${0:t}_$(_timestamp)_errors.txt"
CR=$'\n'

_red() { printf '\e[1;31m%s\e[0m\n' "$1"; }
_green() { printf '\e[1;32m%s\e[0m\n' "$1"; }

_abort() {
	echo
	kill 0
	#pkill -P $$
	trap - SIGINT SIGTERM
	exit 0
}
trap _abort SIGINT SIGTERM

# validate search path
SEARCH_PATH=$(realpath -q $SEARCH_PATH)
[[ -e $SEARCH_PATH ]] || { echo >&2 "invalid search path"; exit 1; }

cat <<EOF > $ERR_LOG
==> run started on $(date)
  | path: ${SEARCH_PATH}${SEARCH_RE:+$CR  | regex: $SEARCH_RE}
  |
EOF

bad=0 ; fc=0; st=$(date +%s)
while read -r -u3 FILENAME ; do
	[[ $DEBUG == true ]] && echo >&2 "processing: $FILENAME"
	read -r SHEBANG < "$FILENAME"
	INTERPRETER=${SHEBANG:2}
	[[ -n $SEARCH_RE ]] && [[ ! $INTERPRETER =~ $SEARCH_RE ]] && continue
	echo "script:  $FILENAME"
	echo "shebang: $SHEBANG"
	for a in ${=INTERPRETER} ; do
		a=${a//$'\r'/}  # handle Windows encoding
		[[ $a == /usr/bin/env ]] && continue
		[[ $a == -* ]] && continue
		[[ -z $a ]] && continue
		if ! command -v "$a" >/dev/null 2>&1 ; then
			_red "*** error: $a does not appear valid"
			(( bad == 0 )) && echo '' >> $ERR_LOG
			echo "$FILENAME" >> $ERR_LOG
			(( bad++ ))
		else
			echo "ok $(_green '✔')"
		fi
		break
	done
	(( fc++ ))
done 3< <(
	find "$SEARCH_PATH" -type f -size -$MAX_SIZE -exec sh -c '
	for f; do
		bytes=$(dd if="$f" bs=1 count=3 2>/dev/null)
		[[ $bytes == "#!/" ]] && echo "$f"
	done'	\
	sh {} +
)

et=$(date +%s)
elapsed=$(( et - st ))

(( bad > 0 )) && echo '' >> $ERR_LOG
cat <<EOF >> $ERR_LOG
  |
==> run completed on $(date)
  | elapsed time: $elapsed second(s)
  | files checked: $fc
  | bad shebang(s) found: $bad
  \____________________________________________________________________________

EOF

if [[ -s $ERR_LOG ]]; then
	if [[ -z $SSH_CONNECTION ]]; then
		open $ERR_LOG
	else
		cat $ERR_LOG
	fi
fi

trap - SIGINT SIGTERM
