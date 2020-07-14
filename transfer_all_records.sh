#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Enter the name of the project to transfer as a single argument. Project names are specified in $(pwd)/config/config.yml."
else
  docker run -it -v="$(pwd)/config:/app/config" -v="$(pwd)/logs:/app/logs" redcap-api-transfer_app:latest ruby transfer_all_records.rb $1
fi