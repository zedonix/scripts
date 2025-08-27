#!/usr/bin/env bash

while true; do
    read -p "> " createFile
    if [[ -z "$createFile" ]]; then
        createFile=$(date +"%Y-%m-%d")
    fi

    filePath=~/Documents/personal/wiki/"$createFile.txt"

    if [[ -e "$filePath" ]]; then
        echo "File already exists. Try a different name."
    else
        break
    fi
done

touch "$filePath"
nvim "$filePath"

# Delete the file if it's empty
if [[ ! -s "$filePath" ]]; then
    rm "$filePath"
fi
