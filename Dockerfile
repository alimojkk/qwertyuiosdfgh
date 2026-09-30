FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tehran
ENV LANG=C.UTF-8
ENV PORT=8080
ENV XUI_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget tar tzdata openssh-server sudo \
    sqlite3 iproute2 net-tools nano htop \
    && rm -rf /var/lib/apt/lists/*

# ---------- 3x-ui panel ----------
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      amd64) XARCH=amd64 ;; \
      arm64) XARCH=arm64 ;; \
      *)     XARCH=amd64 ;; \
    esac; \
    if [ "$XUI_VERSION" = "latest" ]; then \
      URL="https://github.com/MHSanaei/3x-ui/releases/latest/download/x-ui-linux-${XARCH}.tar.gz"; \
    else \
      URL="https://github.com/MHSanaei/3x-ui/releases/download/${XUI_VERSION}/x-ui-linux-${XARCH}.tar.gz"; \
    fi; \
    curl -fsSL -o /tmp/x-ui.tar.gz "$URL"; \
    tar -xzf /tmp/x-ui.tar.gz -C /usr/local/; \
    rm /tmp/x-ui.tar.gz; \
    chmod +x /usr/local/x-ui/x-ui /usr/local/x-ui/bin/xray-linux-${XARCH}; \
    ln -sf /usr/local/x-ui/x-ui /usr/bin/x-ui

RUN mkdir -p /etc/x-ui /data /var/run/sshd /root/.ssh && chmod 700 /root/.ssh

RUN sed -i 's/#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config

COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /usr/local/x-ui
EXPOSE 8080
CMD ["/start.sh"]
