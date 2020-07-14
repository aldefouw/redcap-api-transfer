#!/bin/sh

if [ "$#" -ne 2 ]; then
    echo "Enter the name of the project to transfer as the first argument and the record ID as the second. Project names are specified in $(pwd)/config/config.yml."
else
  docker run -it -v="$(pwd)/config:/app/config" -v="$(pwd)/logs:/app/logs" redcap-api-transfer_app:latest ruby transfer_single_record.rb $1 $2
fi