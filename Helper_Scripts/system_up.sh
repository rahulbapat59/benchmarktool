#!/usr/bin/env bash


exec 3>/dev/tcp/${MACHINE}/22
if [ $? -eq 0 ]
then
    echo "SSH up"
else
    echo "SSH down"
fi