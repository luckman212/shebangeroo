#!/bin/zsh

_usage() {
	cat <<-EOF
	iterates over a directory (and subdirectories) and tests shebangs it finds for validity
	usage: $1 <path> [regex-search] [max_size]
		- use . or leave blank to default to current dir
		- example of regex search could be: \`python\`
		- max_size will default to 128k unless spefified
	EOF
}

case $1 in
	-h|--help) _usage "${0:t}"; exit;;
esac

SEARCH_PATH=${1:-$PWD}
SEARCH_RE=${2:-}
MAX_SIZE=${3:-128k}
ERR_LOG='/private/tmp/errors.txt'

_red() { printf '\e[1;31m%s\e[0m\n' "$1"; }
_green() { printf '\e[1;32m%s\e[0m\n' "$1"; }

_getfiles() {
	find "$SEARCH_PATH" -type f -size -"$MAX_SIZE" -exec sh -c '
	for f; do
		if file "$f" | grep -q text; then
			awk '\''NR==1 {if (/^#!/) {print FILENAME}; exit}'\'' "$f"
		fi
	done' _ {} +
}

cat <<EOF >> $ERR_LOG
==> run started on $(date)
  | path: ${SEARCH_PATH}
  |

EOF

c=0 ; st=$(date +%s)
while read -r -u3 FILENAME ; do
	read -r SHEBANG < "$FILENAME"
	echo "script:  $FILENAME"
	echo "shebang: $SHEBANG"
	INTERPRETER=${SHEBANG:2}
	for a in ${=INTERPRETER} ; do
		[[ $a == /usr/bin/env ]] && continue
		[[ $a == -* ]] && continue
		echo "testing: $a"
		if ! command -v "$a" >/dev/null 2>&1 ; then
			(( c++ ))
			_red "*** error: does not appear valid"
			echo "$FILENAME" >> $ERR_LOG
		else
			echo "ok $(_green '✔')"
		fi
		break
	done
done 3< <(_getfiles)

et=$(date +%s)
elapsed=$(( et - st ))

cat <<EOF >> $ERR_LOG

  |
==> run completed on $(date)
  | elapsed time: $elapsed seconds
  | $c bad shebang(s) found!
  \____________________________________________________________________________

EOF

[[ -s $ERR_LOG ]] && open $ERR_LOG
