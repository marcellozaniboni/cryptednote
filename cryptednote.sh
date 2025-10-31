#!/usr/bin/env bash

##################################
##   CRYPTEDNOTE - version 0.5  ##
##   © Marcello Zaniboni 2025   ##
############################################################################
## This program allows you to manage encrypted personal notes. The        ##
## encryption is based on 7z, which must therefore be installed.          ##
## At the first run, you will be asked for a main password, wich will be  ##
## used to encrypt all your notes. Its hash will be saved in the          ##
## directory CONF_DIR (see below).                                        ##
############################################################################
## This program is free software; you can redistribute it and/or   ##
## modify it under the terms of the GNU General Public License as  ##
## published by the Free Software Foundation; either version 2     ##
## of the License, or (at your option) any later version.          ##
## You should have received a copy of the GNU General Public       ##
## License along with this program (file "LICENSE.txt"); if not,   ##
## visit www.gnu.org/licenses/old-licenses/gpl-2.0.html            ##
##                                                                 ##
## This program is distributed in the hope that it will be useful, ##
## but WITHOUT ANY WARRANTY; without even the implied warranty of  ##
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the    ##
## GNU General Public License for more details.                    ##
#####################################################################

readonly DATA_DIR="$HOME/.local/share/cryptednote"
readonly CONF_DIR="$HOME/.config/cryptednote"
readonly CONF_FILE="$CONF_DIR/cryptednote.cfg"
readonly FALLBACK_EDITOR="nano" # default editor if EDITOR or VISUAL are not set

## returns 0 if the command is not found
function check_command() {
	local cmd=$(which "$1" 2> /dev/null)
	local retval=0
	if [ "$cmd" != "" ]; then
		retval=1
	fi
	echo $retval
}

## trim spaces and delete multiple spaces
function trim_string() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	s="$(echo "$s" | tr -s ' ')"
	printf "%s" "$s"
}

## prints the list of note files, ordered and numbered
## one argument: data directory
function note_list() {
	local datadir="$1"
	local count=$(ls -Q1 "$datadir" | wc -l)
	local i=0
	local f=""
	local len_bytes=0
	local len_kbytes=0
	if [ "$count" -eq "0" ]; then
		echo "the note list is empty"
		return 0
	fi
	cd "$datadir" > /dev/null 2>&1
	let i=1
	for f in *7z; do
		###### TODO - add the timestamp to the list fields
		len_bytes=$(stat --printf="%s" "${f}")
		len_kbytes=$((len_bytes/1024))
		if [ "$len_bytes" -gt 9999 ]; then
			echo -e "${i}. ${f:0:-3}  \e[90m[${len_kbytes} KB]\e[0m"
		else
			echo -e "${i}. ${f:0:-3}  \e[90m[${len_bytes} B]\e[0m"
		fi
		let i=i+1
	done
	cd - > /dev/null 2>&1
}

## gets the compressed file name with full path (the file could not exist)
## argument 1: data directory
## argument 2: note name
function get_compr_file_name() {
	local d="$1"
	local f="$2"
	local fname="$d/$f.7z"
	echo -n "$fname"
}

## gets the temporary work file name with full path (the file could not exist)
## argument 1: work directory
## argument 2: note name
function get_work_file_name() {
	local d="$1"
	local f="$2"
	local fname="$d/$f.txt"
	echo -n "$fname"
}

## returns the note name
## argument 1: data directory
## argument 2: a note number
function get_note_name_by_number() {
	local datadir="$1"
	local n="$2"
	local count=$(ls -Q1 "$datadir" | wc -l)
	local i=0
	local f=""
	if [ "$count" -lt "$n" ]; then
		# the note list is empty
		return 0
	fi
	cd "$datadir" > /dev/null 2>&1
	let i=1
	for f in *7z; do
		if [ "$i" -eq "$n" ]; then
			echo "${f:0:-3}"
			break
		fi
		let i=i+1
	done
	cd - > /dev/null 2>&1
}

## print the error and exit immediately
function print_error_exit() {
	echo -e "\e[91merror\e[0m - $1"
	echo
	exit 1
}

## defining the editor
note_editor="$FALLBACK_EDITOR"
if [ "$EDITOR" != "" ]; then
	note_editor="$EDITOR"
elif [ "$VISUAL" != ""]; then
	note_editor="$VISUAL"
fi

## system commands check
if [ $(check_command "7z") -eq 0 -o \
	$(check_command "whoami") -eq 0 -o \
	$(check_command "clear") -eq 0 -o \
	$(check_command "cut") -eq 0 -o \
	$(check_command "stat") -eq 0 -o \
	$(check_command "tr") -eq 0 -o \
	$(check_command "${note_editor}") -eq 0 -o \
	$(check_command "sha512sum") -eq 0 ]; then
	print_error_exit "one of the following commands not found: 7z, clear, sha512sum, stat, tr, ${note_editor}, whoami"
fi

## check for data dir and create it if it does not exist
if [ ! -d "$DATA_DIR" ]; then
	echo "data directory does not exist"
	mkdir -p "$DATA_DIR"
	chmod 700 "$DATA_DIR"
	echo "data directory has been created"
fi

## check for configuration dir and create it if it does not exist
if [ ! -d "$CONF_DIR" ]; then
	echo "configuration directory does not exist"
	mkdir -p "$CONF_DIR"
	chmod 700 "$CONF_DIR"
	echo "configuration directory has been created"
fi

## check for configuration file and create it with a new main password hash if it does not exist
password=""
if [ ! -f "$CONF_FILE" ]; then
	echo "configuration file does not exist, you must set your main password"
	echo "once you have set it, the password can be reset by manually remove"
	echo "  $CONF_FILE"
	echo "but remember that in this case you will have to manually re-encode"
	echo "note files in this directory using the new password:"
	echo "  $DATA_DIR"
	echo; echo "enter the main password twice"
	read -sp "password (1/2): " pw1; echo
	read -sp "password (2/2): " pw2; echo; echo
	if [ "$pw1" != "$pw2" ]; then
		print_error_exit "the passwords do not match"
	fi
	hash=$(echo -n "$pw1" | sha512sum | cut -d' ' -f1)
	echo "# This configuration file was generated automatically and contains" > "$CONF_FILE"
	echo "# the main password hash." >> "$CONF_FILE"
	echo >> "$CONF_FILE"
	echo "readonly PASSWORD_CHECK=\"${hash}\"" >> "$CONF_FILE"
	echo "configuration file created"; echo
	password="$pw1"
fi

## read/execute the configuration file
source "$CONF_FILE"

## check for temp dir and create it if it does not exist
if [ "$TMPDIR" != "" ]; then
	# this works with Termux
	readonly WORK_DIR="${TMPDIR}/cryptednote-$(whoami)"
else
	readonly WORK_DIR="/tmp/cryptednote-$(whoami)"
fi
if [ ! -d "$WORK_DIR" ]; then
	mkdir -p "$WORK_DIR"
	chmod 700 "$WORK_DIR"
fi

## check if other notes are open in the temp dir and ask for wipe them out
not_closed=$(ls -1 "$WORK_DIR" | wc -l)
if [ "$not_closed" -gt 0 ]; then
	print_error_exit "there are open notes and they are not encrypted: the work directory must be empty when you run this program - look at $WORK_DIR and fix it!"
fi

## read the password and test checksum (if defined)
echo "≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈"
echo "cryptednote v. 0.5"
echo "≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈"
echo
if [ "$password" == "" ]; then
	echo -n "password (will not be echoed): "
	read -s password; echo; echo
	if [ "$PASSWORD_CHECK" != "" ]; then
		if [ "$PASSWORD_CHECK" != "$(echo -n "$password" | sha512sum | cut -d' ' -f1)" ]; then
			print_error_exit "wrong password"
		fi
	fi
fi
password=$(printf "%q" "$password") # escape dangerous chars like spaces

## main menu
note_list "$DATA_DIR"
echo
echo "Enter"
echo " - a number to edit a note (e.g. \"2\" to edit the 2nd note)"
echo " - a negative number to delete a note (e.g. \"-4\" to delete the 4th note)"
echo " - \"0\" to create a new one"
echo " - \"q\" to quit"
while true; do
    read -p "Your choice: " n
   	if [ "${n,,}" == "q" ]; then clear; exit 0; fi
    if [[ "$n" =~ ^-?[0-9]+$ ]]; then
        break
    fi
done

## new note
if [ "$n" -eq "0" ]; then
	# ask for the new note name and trim it
	echo -n "new note name: "
	read notename
	notename=$(trim_string "$notename")
	if [ "$notename" == "" ]; then
		print_error_exit "empty string"
	fi

	# check for name collision with existing notes
	compr_fname=$(get_compr_file_name "$DATA_DIR" "$notename")
	if [ -f "$compr_fname" ]; then
		print_error_exit "this name already exists"
	fi

	# create a new note in the work directory and open it
	work_fname=$(get_work_file_name "$WORK_DIR" "$notename")
	echo "This is a new note: you can delete this text." > "$work_fname"
	echo "After editing this file, when you close the editor, it will be encripted." >> "$work_fname"
	$note_editor "$work_fname"

	# compress the note in the data dir
	cd "$WORK_DIR"
	7z a -mhe=on -p${password} "$compr_fname" "${notename}.txt"
	status=$?
	if [ "$status" -ne "0" ]; then
		echo "Error while encrypting the note recover manually the temporary file:"
		echo "  $work_fname"
	else
		# delete the file in the work dir
		rm "$work_fname"
		clear
	fi
	cd - > /dev/null 2>&1


## edit or delete an existing note
else
	notenumber=$(( n < 0 ? -n : n ))
	delete="false"; if [ "$n" -lt "0" ]; then delete="true"; fi
	notename="$(get_note_name_by_number "$DATA_DIR" $notenumber)"
	if [ "$notename" != "" ]; then
		work_fname=$(get_work_file_name "$WORK_DIR" "$notename")
		compr_fname=$(get_compr_file_name "$DATA_DIR" "$notename")
		echo "note name: \"$notename\""
		echo "delete: \"$delete\""                     ####### REMOVE THIS LINE
		echo "work file name: \"$work_fname\""         ####### REMOVE THIS LINE
		echo "compressed file name: \"$compr_fname\""  ####### REMOVE THIS LINE

		if [ "$delete" == "true" ]; then
			## delete an existing note
			rm "$compr_fname"
		else
			## edit an existing note
			cd "$WORK_DIR"
			7z x -p${password} "$compr_fname"
			if [ ! -f "$work_fname" ]; then
				print_error_exit "cannot find the file $work_fname"
			fi
			clear
			work_fname_hash_t0=$(sha512sum "$work_fname" | cut -f1 -d' ')
			$note_editor "$work_fname"
			work_fname_hash_t1=$(sha512sum "$work_fname" | cut -f1 -d' ')
			if [ "$work_fname_hash_t0" != "$work_fname_hash_t1" ]; then
				rm "$compr_fname"
				7z a -mhe=on -p${password} "$compr_fname" "${notename}.txt"
				status=$?
				if [ "$status" -ne "0" ]; then
					echo "Error while encrypting the note recover manually the temporary file:"
					echo "  $work_fname"
				else
					rm "$work_fname" # delete the file in the work dir
					clear
				fi
			else
				rm "$work_fname" # delete the file in the work dir
				echo
				echo "The note has not changed; nothing to do."
			fi
			cd - > /dev/null 2>&1
		fi
	else
		print_error_exit "note not found"
	fi
fi
