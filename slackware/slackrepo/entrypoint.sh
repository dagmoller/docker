#!/bin/bash

if [ -d /var/lib/slackrepo/.gnupg ]; then
	rm -rf ~/.gnupg
	cp -a /var/lib/slackrepo/.gnupg ~/.gnupg
else
	cp -a ~/.gnupg /var/lib/slackrepo/
fi

/bin/bash -l

