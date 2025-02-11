FROM mcr.microsoft.com/dotnet/runtime-deps:8.0-jammy AS runner-build

ARG PY_VERSION=3.10
ARG RUNNER_VERSION="2.322.0"
ARG RUNNER_ARCH="arm64"
ARG RUNNER_CONTAINER_HOOKS_VERSION="0.6.2"

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

ENV PATH=/usr/local/python${PY_VERSION}/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:${LD_LIBRARY_PATH}

RUN apt update -y && \
    apt install curl unzip -y && \
    apt install -y \
        apt-transport-https \
        ca-certificates \
        bash \
        libc6 \
        libsqlite3-dev

RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

WORKDIR /home/runner

RUN curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

# Copy files
COPY --from=ascendai/cann:latest /usr/local/python${PY_VERSION} /usr/local/python${PY_VERSION}
COPY --from=ascendai/cann:latest /usr/local/Ascend /usr/local/Ascend
COPY --from=ascendai/cann:latest /etc/Ascend /etc/Ascend

# Set environment variables
RUN \
    # Set environment variables for Python \
    PY_PATH="PATH=/usr/local/python${PY_VERSION}/bin:\${PATH}" && \
    echo "export ${PY_PATH}" >> /etc/profile && \
    echo "export ${PY_PATH}" >> ~/.bashrc && \
    # Set environment variables for CANN \
    CANN_TOOLKIT_ENV_FILE="/usr/local/Ascend/ascend-toolkit/set_env.sh" && \
    DRIVER_LIBRARY_PATH="LD_LIBRARY_PATH=/usr/local/Ascend/driver/lib64/common:/usr/local/Ascend/driver/lib64/driver:\${LD_LIBRARY_PATH}" && \
    echo "export ${DRIVER_LIBRARY_PATH}" >> /etc/profile && \
    echo "export ${DRIVER_LIBRARY_PATH}" >> ~/.bashrc && \
    echo "source ${CANN_TOOLKIT_ENV_FILE}" >> /etc/profile && \
    echo "source ${CANN_TOOLKIT_ENV_FILE}" >> ~/.bashrc

ENTRYPOINT [ "/bin/bash", "-c", "source /usr/local/Ascend/ascend-toolkit/set_env.sh && exec \"$@\"", "--" ]

USER runner
