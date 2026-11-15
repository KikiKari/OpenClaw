FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.title="abstractions-manager"
LABEL org.opencontainers.image.source="https://github.com/KikiKari/OpenClaw"

RUN test "$(dpkg --print-architecture)" = amd64 \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git nodejs perl ruby lua5.4 tcl golang-go rakudo \
 && curl -fsSL https://github.com/PowerShell/PowerShell/releases/download/v7.7.0/powershell_7.7.0-1.deb_amd64.deb -o /tmp/powershell.deb \
 && echo 'BECB565095BA0569E1B6D18055CE1114A426523145E6E5AC856928F6B9B013C4  /tmp/powershell.deb' | sha256sum -c - \
 && apt-get install -y --no-install-recommends /tmp/powershell.deb \
 && rm -f /tmp/powershell.deb \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --uid 10001 --create-home lauf \
 && mkdir -p /home/openclaw/.openclaw/workspace \
 && chown -R lauf:lauf /home/openclaw

WORKDIR /app
COPY ABSTRACTIONS_MANAGER.py github_publisher.py /app/
COPY run.sh /usr/local/bin/abstractions-manager
RUN chmod 755 /usr/local/bin/abstractions-manager
USER lauf

ENV ABSTRACTIONS_EXECUTION=standalone \
    ABSTRACTIONS_WORKSPACE=/home/openclaw/.openclaw/workspace \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=Europe/Berlin
CMD ["/usr/local/bin/abstractions-manager"]
