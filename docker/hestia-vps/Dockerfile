FROM ubuntu:22.04

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		bash \
		ca-certificates \
		curl \
		dbus \
		iproute2 \
		lsb-release \
		openssh-server \
		systemd \
		systemd-sysv \
		tini \
		wget \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /lib/systemd/system/multi-user.target.wants/* \
		/etc/systemd/system/*.wants/* \
		/lib/systemd/system/local-fs.target.wants/* \
		/lib/systemd/system/sockets.target.wants/*udev* \
		/lib/systemd/system/sockets.target.wants/*initctl* \
		/lib/systemd/system/systemd-update-utmp*

WORKDIR /workspace
COPY . /workspace

VOLUME ["/sys/fs/cgroup"]

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]
