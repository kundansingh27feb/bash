#!/bin/bash
err_file=$(mktemp)
mkdir /opt/k8test 2>"$err_file"
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
    echo "Directory Created"
else
    echo "Not able to create the directory. Kindly find the error below:"
    cat "$err_file"
fi
rm "$err_file"


err_fi=$(mktemp)
mkdir /opt/testt 2> "$err_fi"
exit_code=$?
if [ "" ]