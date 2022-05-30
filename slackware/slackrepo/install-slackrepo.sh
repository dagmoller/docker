#!/bin/bash

##
## Download and install slackrepo
##
source /etc/os-release

case $VERSION in
	14.2)
		git clone https://github.com/idlemoor/slackrepo.git
		cd slackrepo
		git checkout v0.2.0rc1-170-g65b100d
		gitrev=git$(git log -n 1 --format=format:%h .)
		git archive --format=tar --prefix=slackrepo-$gitrev/ HEAD | gzip > SlackBuild/slackrepo-$gitrev.tar.gz
		cd SlackBuild
		VERSION=$gitrev TAG=_github sh ./slackrepo.SlackBuild
		upgradepkg --install-new /tmp/slackrepo-$gitrev-noarch-1_github.t?z
		cd ../../
		rm -rf slackrepo

		git clone https://github.com/idlemoor/slackrepo-hints.git
		cd slackrepo-hints
		git checkout 20170817-2-g6d7e730
		gitrev=git$(git log -n 1 --format=format:%h .)
		git archive --format=tar --prefix=slackrepo-hints-$gitrev/ HEAD | gzip > SlackBuild/slackrepo-hints-$gitrev.tar.gz
		cd SlackBuild
		VERSION=$gitrev TAG=_github sh ./slackrepo-hints.SlackBuild
		upgradepkg --install-new /tmp/slackrepo-hints-$gitrev-noarch-1_github.t?z
		cd ../../
		rm -rf slackrepo-hints
	;;

	15.0)
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
		upgradepkg --install-new /tmp/slackrepo*.t?z

		rm -rf /slackrepo* /root/slackrepo* /tmp/slackrepo*.t?z
	;;
esac

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
REPO=SBo
TAG='$repoTag'
CHROOT='n'

USE_GENREPOS='$useGenRepos'
REPOSOWNER='$gpgName <$gpgEmail>'
RSS_TITLE='$rssTitle'
RSS_UUID='$(uuidgen -t)'
EOF

