#!/bin/sh

set -e

echo "> Copying settings"
cp -rf /data/projects/dknr-alexa/package.json /data/package.json
cp -rf /data/projects/dknr-alexa/data/settings.js /data/settings.js
cp -rf /data/projects/dknr-alexa/data/.config.projects.json /data/.config.projects.json
cp -rf /data/projects/dknr-alexa/data/admin.png /data/admin.png
echo "> Preparing credentials"
cd /data
sed -i -e "s|DKNR_USERNAME|${DKNR_USERNAME}|g" settings.js
sed -i -e "s|DKNR_HASH|$(expr substr "$(echo "${DKNR_PASSWORD}" | node-red admin hash-pw)" 11 100)|g" settings.js
sed -i -e "s|DKNR_SECRET|${DKNR_SECRET}|g" settings.js
# Amazon connection credentials (VSH certificates) are encrypted with DKNR_SECRET
sed -i -e "s|DKNR_SECRET|${DKNR_SECRET}|g" .config.projects.json
echo "> Instaling packages"
npm install --unsafe-perm --no-update-notifier --no-fund --omit=dev
echo "> Running node-red"
cd /usr/src/node-red
/usr/src/node-red/entrypoint.sh node-red
