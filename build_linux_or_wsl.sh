#!/usr/bin/env bash

#Run with WSL!
# TODO: check if dist exists (and is directory), skip mkdir if it does.
read -p "Please input your Battlezone 98 Redux directory " bzd

mkdir ./dist
for filename in src/*; do
  	if ! [[ $filename == "src/*.bin" ]]; then
      cp -r $filename dist/
      echo "copying $filename"
    fi
done
echo "linking files to $bzd :"
ln -sv ./dist/* $bzd/Addon/
