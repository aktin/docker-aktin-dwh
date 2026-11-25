FROM python:__PYTHON_VERSION__

ARG BUILD_TIME
LABEL org.opencontainers.image.created=${BUILD_TIME} \
    org.opencontainers.image.authors="akombeiz@ukaachen.de, shuening@ukaachen.de, skurka@ukaachen.de" \
    org.opencontainers.image.source="https://github.com/aktin/docker-aktin-dwh" \
    org.opencontainers.image.version="__DWH_GITHUB_TAG__" \
    org.opencontainers.image.revision="__MELD_CONTAINER_REVISION__" \
    org.opencontainers.image.vendor="AKTIN" \
    org.opencontainers.image.title="MELD Orchestrator" \
    org.opencontainers.image.description="The MELD (Medical Learning and Deployment) Orchestrator enables clinicians and researchers\
to run their own trained ML models." \
    org.opencontainers.image.base.digest="__BASE_DIGEST__"

RUN mkdir -p /logs /contracts /schedules

WORKDIR /app

COPY . ./

RUN printf "%s" meld > ./db_password

ENV DB_USER=meld \
    DB_NAME=i2b2 \
    DB_PASSWORD_FILE=/app/db_password

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata gosu \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash meld \
    && pip install --no-cache-dir -r ./requirements.txt gunicorn \
    && chown -R meld:meld /logs /contracts /schedules

USER root
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "1", "--threads", "4", "--access-logfile", "-", "--error-logfile", "-", "app:create_app()"]
