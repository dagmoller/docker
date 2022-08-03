
FROM liveslak/slackware:base_x64_14.2
ARG slackwareMirror
COPY full-install.sh /
RUN chmod 755 /full-install.sh && /full-install.sh && rm /full-install.sh

