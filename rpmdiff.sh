#!/bin/bash
#   rpmdiff : a simple rpmnew/rpmsave/rpmorig updater
#
#   Copyright (c) 2018 Martin Födinger <martin@foedinger.ml>
#
#   Original script taken from pacdiff (https://git.archlinux.org/pacman-contrib.git/tree/src/pacdiff.sh.in?id=2197352aca3b3554e891fe4397bc30649f5c6cbd) on 2018-07-23. Pacdiff is written by these guys:
#   Copyright (c) 2007 Aaron Griffin <aaronmgriffin@gmail.com>
#   Copyright (c) 2013-2016 Pacman Development Team <pacman-dev@archlinux.org>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

shopt -s extglob

declare -r myname='rpmdiff'
declare -r myver='1.0'

diffprog=${DIFFPROG:-'vim -d'}
diffsearchpath=${DIFFSEARCHPATH:-/etc}
USE_COLOR='y'
declare -a oldsaves
declare -i USE_FIND=0 USE_LOCATE=0 OUTPUTONLY=0

#format outputs
plain() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${BOLD}    ${mesg}${ALL_OFF}\n" "$@" >&1
}

msg() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&1
}

msg2() {
	(( QUIET )) && return
	local mesg=$1; shift
	printf "${BLUE}  ->${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&1
}

ask() {
	local mesg=$1; shift
	printf "${BLUE}::${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}" "$@" >&1
}

warning() {
	local mesg=$1; shift
	printf "${YELLOW}==> $(gettext "WARNING:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

error() {
	local mesg=$1; shift
	printf "${RED}==> $(gettext "ERROR:")${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

usage() {
  cat <<EOF
${myname} v${myver}

A simple program to merge or remove rpmnew/rpmsave/rpmorig files.

Usage: $myname [-l | -f | -p] [--nocolor]

Search Options:     select one (default: --find)
  -l/--locate       scan using locate
  -f/--find         scan using find

General Options:
  -o/--output       print files instead of merging them
  --nocolor         remove colors from output

Environment Variables:
  DIFFPROG          override the merge program: (default: 'vim -d')
  DIFFSEARCHPATH    override the search path. (only when using find)
                    (default: /etc)

Example: DIFFPROG=meld DIFFSEARCHPATH="/boot /etc /usr" $myname
Example: $myname --output --locate

EOF
}

version() {
  printf "%s %s\n" "$myname" "$myver"
	echo 'Copyright (C) 2018 Martin Födinger <martin@foedinger.ml>'
	echo
	echo 'Original pacdiff script from these guys:'
	echo '2007 Aaron Griffin <aaronmgriffin@gmail.com>'
  echo '2013-2016 Pacman Development Team <pacman-dev@archlinux.org>'
}

print_existing() {
  [[ -f "$1" ]] && printf '%s\0' "$1"
}

print_existing_rpmsave(){
  for f in "${1}"?(.+([0-9])); do
    [[ -f $f ]] && printf '%s\0' "$f"
  done
}

cmd() {
  if (( USE_LOCATE )); then
    locate -0 -e -b \*.rpmnew \*.rpmorig \*.rpmsave '*.rpmsave.[0-9]*'
  elif (( USE_FIND )); then
    find $diffsearchpath \( -name \*.rpmnew -o -name \*.rpmorig -o -name \*.rpmsave -o -name '*.rpmsave.[0-9]*' \) -print0
  fi
}

while [[ -n "$1" ]]; do
  case "$1" in
    -l|--locate)
      USE_LOCATE=1;;
    -f|--find)
      USE_FIND=1;;
    -o|--output)
      OUTPUTONLY=1;;
    --nocolor)
      USE_COLOR='n';;
    -V|--version)
      version; exit 0;;
    -h|--help)
      usage; exit 0;;
    *)
      usage; exit 1;;
  esac
  shift
done

# check if messages are to be printed using color
unset ALL_OFF BOLD BLUE GREEN RED YELLOW
if [[ -t 2 && ! $USE_COLOR = "n" ]]; then
	# prefer terminal safe colored and bold text when tput is supported
	if tput setaf 0 &>/dev/null; then
		ALL_OFF="$(tput sgr0)"
		BOLD="$(tput bold)"
		BLUE="${BOLD}$(tput setaf 4)"
		GREEN="${BOLD}$(tput setaf 2)"
		RED="${BOLD}$(tput setaf 1)"
		YELLOW="${BOLD}$(tput setaf 3)"
	else
		ALL_OFF="\e[1;0m"
		BOLD="\e[1;1m"
		BLUE="${BOLD}\e[1;34m"
		GREEN="${BOLD}\e[1;32m"
		RED="${BOLD}\e[1;31m"
		YELLOW="${BOLD}\e[1;33m"
	fi
fi
readonly ALL_OFF BOLD BLUE GREEN RED YELLOW


if ! type -p ${diffprog%% *} >/dev/null && (( ! OUTPUTONLY )); then
  error "Cannot find the $diffprog binary required for viewing differences."
  exit 1
fi

case $(( USE_FIND + USE_LOCATE)) in
  0) USE_FIND=1;; # set the default search option
  [^1]) error "Only one search option may be used at a time"
    usage; exit 1;;
esac

# see http://mywiki.wooledge.org/BashFAQ/020
while IFS= read -u 3 -r -d '' rpmfile; do
  file="${rpmfile%.rpm*}"
  file_type="rpm${rpmfile##*.rpm}"

  if (( OUTPUTONLY )); then
    echo "$rpmfile"
    continue
  fi

  # add matches for rpmsave.N to oldsaves array, do not prompt
  if [[ $file_type = rpmsave.+([0-9]) ]]; then
    oldsaves+=("$rpmfile")
    continue
  fi

  msg "%s file found for %s" "$file_type" "$file"
  if [ ! -f "$file" ]; then
    warning "$file does not exist"
    rm -iv "$rpmfile"
    continue
  fi

  if cmp -s "$rpmfile" "$file"; then
    msg2 "Files are identical, removing..."
    rm -v "$rpmfile"
  else
    ask "(V)iew, (S)kip, (R)emove %s, (O)verwrite with %s, (Q)uit: [v/s/r/o/q] " "$file_type" "$file_type"
    while read c; do
      case $c in
        q|Q) exit 0;;
        r|R) rm -v "$rpmfile"; break ;;
        o|O) mv -v "$rpmfile" "$file"; break ;;
        v|V)
          $diffprog "$rpmfile" "$file"
          ask "(V)iew, (S)kip, (R)emove %s, (O)verwrite with %s, (Q)uit: [v/s/r/o/q] " "$file_type" "$file_type";
          continue ;;
        s|S) break ;;
        *) ask "Invalid answer. Try again: [v/s/r/o/q] "; continue ;;
      esac
    done
  fi
done 3< <(cmd)

(( ${#oldsaves[@]} )) && warning "Ignoring %s" "${oldsaves[@]}"

exit 0

# vim: set noet: