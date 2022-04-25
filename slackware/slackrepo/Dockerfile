
FROM slackware:full_x64_15.0
COPY install-slackrepo.sh /

VOLUME /var/lib/slackrepo
WORKDIR /root

ARG repoTag=dag
ARG useGenRepos=1
ARG gpgName="Diego Aguirre"
ARG gpgEmail="aguirre@dagcs.com"
ARG rssTitle="DagMoller Slackware Packages"

RUN chmod 755 /install-slackrepo.sh && \
	./install-slackrepo.sh && \
	rm -rf install-slackrepo.sh

