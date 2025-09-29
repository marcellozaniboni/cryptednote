# cryptednote

a small bash script to manage personal encrypted notes on your computer

## About

This small script uses 7z to conveniently manage the encryption of personal and private notes.  
It has been tested on Linux (native and on WSL) and on Android via Termux app, but should also work on other platforms where a Bash shell is installed and the commands used by the script are available.

## How it works

At the first use, the user is prompted to enter a main password, which will be used for the encryption of all their notes. The password SHA512 checksum will be written to the configuration file `$HOME/.config/cryptednote.cfg`.

The notes created by the user are actually 7z archives, which contain a text file.

All notes are stored in the `$HOME/.local/share/cryptednote`. When a user wants to edit or view a note, the text file is temporarily extracted to `/tmp/cryptednote-$USER` or in Termux to `$TMPDIR/cryptednote-$USER`. It is therefore important to note that when editing a note, it will be temporarily written in plain text to the filesystem, even though access to the folder is restricted to the user who owns the note.