FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		bash \
		ca-certificates \
		curl \
		file \
		gnupg \
		iproute2 \
		lsb-release \
		nginx \
		procps \
		shellcheck \
		socat \
		tini \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.goaccess.io/gnugpg.key \
	| gpg --dearmor -o /usr/share/keyrings/goaccess.gpg \
	&& echo "deb [signed-by=/usr/share/keyrings/goaccess.gpg arch=$(dpkg --print-architecture)] https://deb.goaccess.io/ $(lsb_release -cs) main" \
		> /etc/apt/sources.list.d/goaccess.list \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends goaccess \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY . /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
