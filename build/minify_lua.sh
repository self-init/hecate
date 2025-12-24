#!/bin/bash
# Performs some basic minifying to keep the file size down

# Remove multiline comments
sed -i '/--\[\[/,/\]\]/d' "$1"
# Removes single line comments
sed -i 's/[[:space:]]*--.*$//g' "$1"
# Removes empty/whitespace lines
sed -i '/^[[:space:]]*$/d' "$1"
