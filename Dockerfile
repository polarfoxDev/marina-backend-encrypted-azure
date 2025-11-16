FROM alpine:3.22

RUN apk add --no-cache --update \
    gpg  \
    gpg-agent \
    bash \
    python3 \
    py3-pip \
    gcc \
    musl-dev \
    python3-dev \
    libffi-dev \
    openssl-dev \
    cargo \
    make

# Create and activate a virtual environment for Azure CLI
RUN python3 -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip install --upgrade pip \
    && pip install --no-cache-dir azure-cli \
    && deactivate

# Clean up unnecessary build tools
RUN apk del \
    gcc \
    musl-dev \
    python3-dev \
    libffi-dev \
    openssl-dev \
    cargo \
    make \
    && rm -rf /var/cache/apk/*

# Update PATH to include the virtual environment
ENV PATH="/opt/venv/bin:$PATH"

COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

# The backup script will be executed by Marina
ENTRYPOINT ["/backup.sh"]
