#!/bin/bash

##
## Download and install slackrepo
##
slackrepo=${slackrepo:-https://www.slackbuilds.org/slackbuilds/15.0/system/slackrepo.tar.gz}
slackrepoHints=${slackrepoHints:-https://www.slackbuilds.org/slackbuilds/15.0/system/slackrepo-hints.tar.gz}

wget $slackrepo $slackrepoHints
tar -xf slackrepo.tar.gz
tar -xf slackrepo-hints.tar.gz

cd slackrepo
source slackrepo.info
wget $DOWNLOAD
./slackrepo.SlackBuild

cd ../slackrepo-hints
source slackrepo-hints.info
wget $DOWNLOAD
./slackrepo-hints.SlackBuild

cd /
installpkg /tmp/slackrepo*.t?z

rm -rf /slackrepo* /root/slackrepo* /tmp/slackrepo*.t?z

## Generate GPG
cat > gen-key-script << EOF
Key-Type: 1
Key-Length: 2048
Subkey-Type: 1
Subkey-Length: 2048
Name-Real: $gpgName
Name-Email: $gpgEmail
Expire-Date: 0
EOF

gpg --batch --gen-key gen-key-script
rm -rf gen-key-script

cat > ~/.slackreporc << EOF
TAG='$repoTag'
CHROOT='n'

USE_GENREPOS='$useGenRepos'
REPOSOWNER='$gpgName <$gpgEmail>'
RSS_TITLE='$rssTitle'
RSS_UUID='$(uuidgen -t)'
EOF

