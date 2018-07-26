#!/bin/bash

set -e
set -o pipefail

GIT_MAIL="cloudalchemybot@gmail.com"
GIT_USER="cloudalchemybot"

if [ -z "${GITHUB_TOKEN}" ]; then
    echo -e "\e[31mGitHub token (GITHUB_TOKEN) not set. Terminating.\e[0m"
    exit 1
fi

if [ -z "${SRC}" ]; then
    echo -e "\e[31mNo source repository set (SRC). Terminating.\e[0m"
    exit 1
fi

if [ -z "${DST}" ]; then
    echo -e "\e[31mNo destination repository set (SRC). Terminating.\e[0m"
    exit 1
fi

# Get new version
VERSION="$(curl --silent "https://api.github.com/repos/${SRC}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//')"
echo -e "\e[32mNew ${SRC} version is: ${VERSION}\e[0m"

# Download destination repository
ORIG=$(pwd)
git clone "https://github.com/${DST}" "${DST}"
sed -i "s/_version:.*$/_version: ${VERSION}/" "${DST}/defaults/main.yml"
cd "${DST}"
if [ -z "$(git diff-index --name-only HEAD --)" ]; then
    echo -e "\e[32mNothing changed.\e[0m"
    exit 0
fi
cd $ORIG

# Download hub
HUB_VERSION="2.5.0"
wget "https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz"
tar -xvf "hub-linux-amd64-${HUB_VERSION}.tgz"
cp "hub-linux-amd64-${HUB_VERSION}/bin/hub" ./
chmod +x hub
export PATH="${PATH}:${ORIG}"

# Push new version
cd "${DST}"
git config user.email "${GIT_MAIL}"
git config user.name "${GIT_USER}"
git checkout -b autoupdate
git add "defaults/main.yml"
git commit -m ':tada: automated upstream release update'
echo -e "\e[32mPushing to autoupdate branch in ${DST}\e[0m"
git push "https://${GITHUB_TOKEN}:@github.com/${DST}" --set-upstream autoupdate || exit 1
REPO="$(echo $SRC | awk -F '/' '{print $2}' )"
export GITHUB_TOKEN=$GITHUB_TOKEN
hub pull-request -h autoupdate -F- <<< "New ${REPO} upstream release!

Guys at [${SRC}](https://github.com/${SRC}) released new software version - $VERSION! This PR updates code to bring that version into this repository.

This is an automated PR, if you don't want to receive those, please contact @paulfantom."

echo -e "\e[32mPull Request with new version is ready\e[0m"
