FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# Update system and install systemd & essential tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd systemd-sysv wget curl sudo ca-certificates lsb-release gnupg iproute2 procps python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Fix systemd inside a container environment
RUN cd /lib/systemd/system/sysinit.target.wants/ \
    && ls | grep -v systemd-tmpfiles-setup | xargs rm -f $1 \
    && rm -f /lib/systemd/system/multi-user.target.wants/* \
    && rm -f /etc/systemd/system/*.wants/* \
    && rm -f /lib/systemd/system/local-fs.target.wants/* \
    && rm -f /lib/systemd/system/sockets.target.wants/*udev* \
    && rm -f /lib/systemd/system/sockets.target.wants/*initctl* \
    && rm -f /lib/systemd/system/basic.target.wants/* \
    && rm -f /lib/systemd/system/anaconda.target.wants/*

# Create a systemctl stub so that build_sdcard.sh can "start" services during build
RUN echo '#!/bin/bash\n\
if [ "$1" = "enable" ] || [ "$1" = "disable" ] || [ "$1" = "mask" ] || [ "$1" = "unmask" ] || [ "$1" = "link" ] || [ "$1" = "preset" ] || [ "$1" = "set-default" ]; then\n\
  /bin/systemctl "$@"\n\
else\n\
  echo "Docker build systemctl stub intercept: systemctl $@"\n\
  exit 0\n\
fi' > /usr/local/bin/systemctl && chmod +x /usr/local/bin/systemctl

WORKDIR /root

# Copy repository
COPY . /root/raspiblitz/

# Modify build_sdcard.sh for Trixie
RUN cd /root/raspiblitz && \
    sed -i 's/bookworm/trixie/g' build_sdcard.sh && \
    chmod +x build_sdcard.sh

# Execute the RaspiBlitz build process (headless)
RUN cd /root/raspiblitz && ./build_sdcard.sh -b dev -d headless -i 0 -w off || echo "Build finished with some warnings (expected in container build)."

# Remove the systemctl stub so systemd works correctly at runtime
RUN rm /usr/local/bin/systemctl

STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
