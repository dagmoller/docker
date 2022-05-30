
ARG slackVer=15.0

FROM slackware:full_x64_${slackVer}

COPY . .

ENTRYPOINT /entrypoint.sh
VOLUME /var/lib/slackrepo
WORKDIR /root

ARG repoTag=dag
ARG useGenRepos=1
ARG gpgName="Diego Aguirre"
ARG gpgEmail="aguirre@dagcs.com"
ARG rssTitle="DagMoller Slackware Packages"

RUN \
	chmod 755 /entrypoint.sh && \
	chmod 755 /install-slackrepo.sh && \
	\
	/install-slackrepo.sh && \
	rm -rf /install-slackrepo.sh && \
	rm -rf /Dockerfile

