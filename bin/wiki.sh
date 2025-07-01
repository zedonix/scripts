#!/bin/bash

while true; do
    read -p "> " createFile
    if [[ -z "$createFile" ]]; then
        createFile=$(date +"%Y-%m-%d")
    fi

    filePath=~/wiki/"$createFile.md"

    if [[ -e "$filePath" ]]; then
        echo "File already exists. Try a different name."
    else
        break
    fi
done

touch "$filePath"
nvim "$filePath"

# Delete the file if it's empty (size 0)
if [[ ! -s "$filePath" ]]; then
    rm "$filePath"
    echo "Empty file deleted."
fi
