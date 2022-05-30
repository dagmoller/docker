#!/bin/bash

if [ -d /var/lib/slackrepo/.gnupg ]; then
	rm -rf ~/.gnupg
	cp -a /var/lib/slackrepo/.gnupg ~/.gnupg
else
	cp -a ~/.gnupg /var/lib/slackrepo/
fi

if [ -f /var/lib/slackrepo/.slackreporc ]; then
	rm -rf ~/.slackreporc
	cp -a /var/lib/slackrepo/.slackreporc ~/.slackreporc
else
	cp -a ~/.slackreporc /var/lib/slackrepo/.slackreporc
fi

/bin/bash -l

