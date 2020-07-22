#!/bin/sh

#Get the tags from server
git fetch --tags

#Get the latest tag
latest_tag=$(git tag | tail -1)

#Ask the user what tag they want to deploy from
echo Latest tag: $latest_tag
echo What tag do you want to deploy from?  Blank deploys from latest.

read user_input_tag

#By default, we're selecting the latest tag
selected_tag=$latest_tag

#If they've specific a tag, let's use that instead
if [[ ${#user_input_tag} -gt 0 ]]
then
  selected_tag=$user_input_tag
fi

#
echo ====================================
echo Deployment Tag: $selected_tag.
echo ====================================

#Pull the repo
git pull

#Checkout the repo by tagged release
git checkout tags/$selected_tag

#Rebuild the image if needed based upon the docker-compose.yml file
docker-compose build redcap-api-file-transfer