FROM python:__PYTHON_VERSION__

ARG BUILD_TIME
LABEL org.opencontainers.image.created="${BUILD_TIME}"
LABEL org.opencontainers.image.version="__MELD_GITHUB_TAG__"
LABEL org.opencontainers.image.revision="__MELD_CONTAINER_REVISION__"
LABEL org.opencontainers.image.title="MELD Orchestrator"
LABEL org.opencontainers.image.description="The MELD (Medical Learning and Deployment) Orchestrator enables clinicians and researchers\
to run their own trained ML models."
LABEL org.opencontainers.image.source="https://github.com/aktin/MELD"

WORKDIR /

RUN mkdir -p /logs /contracts /schedules /app

WORKDIR /app

COPY *.py ./
COPY VERSION ./
COPY entrypoint.sh ./
COPY requirements.txt ./requirements.txt
COPY InternalDataLoader ./InternalDataLoader
COPY ModelEnvironment ./ModelEnvironment
COPY ExecutionScheduler ./ExecutionScheduler
COPY ModelManager ./ModelManager
COPY ExecutionMonitor ./ExecutionMonitor
COPY utils ./utils
COPY Logger ./Logger
COPY resources ./resources
COPY Server ./Server

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates tzdata gosu \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash meld \
    && pip install --no-cache-dir -r ./requirements.txt gunicorn \
    && chown -R meld:meld /logs /contracts /schedules

USER root
ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
CMD ["sh", "-c", "exec gunicorn --bind 0.0.0.0:5000 --workers 1 --threads 4 --access-logfile - --error-logfile - 'app:create_app()'"]
