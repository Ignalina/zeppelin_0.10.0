#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
FROM maven:3.5-jdk-8 as builder
ADD . /workspace/zeppelin
WORKDIR /workspace/zeppelin
# Allow npm and bower to run with root privileges
RUN echo "unsafe-perm=true" > ~/.npmrc && \
    echo '{ "allow_root": true }' > ~/.bowerrc && \
    mvn -B package -Denforcer.skip=true -DskipTests -Pbuild-distr -Pspark-3.1 -Pinclude-hadoop -Phadoop3 -Pspark-scala-2.12 -Pweb-angular && \

    # Example with doesn't compile all interpreters
    # mvn -B package -DskipTests -Pbuild-distr -Pspark-3.0 -Pinclude-hadoop -Phadoop3 -Pspark-scala-2.12 -Pweb-angular -pl '!groovy,!submarine,!livy,!hbase,!pig,!file,!flink,!ignite,!kylin,!lens' && \
    mv /workspace/zeppelin/zeppelin-distribution/target/zeppelin-*/zeppelin-* /opt/zeppelin/ && \
    # Removing stuff saves time, because docker creates a temporary layer
    rm -rf ~/.m2 && \
    rm -rf /workspace/zeppelin/*

FROM ubuntu:20.04
COPY --from=builder /opt/zeppelin /opt/zeppelin

LABEL maintainer="Apache Software Foundation <dev@zeppelin.apache.org>"

ENV Z_VERSION="0.10.0"

ENV LOG_TAG="[ZEPPELIN_${Z_VERSION}]:" \
    ZEPPELIN_HOME="/opt/zeppelin" \
    HOME="/opt/zeppelin" \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    ZEPPELIN_ADDR="0.0.0.0"

RUN echo "$LOG_TAG install basic packages" && \
    apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y locales language-pack-en tini openjdk-8-jre-headless wget unzip && \
    # Cleanup
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoclean && \
    apt-get clean

# Install conda to manage python and R packages
ARG miniconda_version="py37_4.9.2"
# Hashes via https://docs.conda.io/en/latest/miniconda_hashes.html
ARG miniconda_sha256="79510c6e7bd9e012856e25dcb21b3e093aa4ac8113d9aa7e82a86987eabe1c31"
# Install python and R packages via conda
COPY env_python_3_with_R.yml /env_python_3_with_R.yml

RUN set -ex && \
    wget -nv https://repo.anaconda.com/miniconda/Miniconda3-${miniconda_version}-Linux-x86_64.sh -O miniconda.sh && \
    echo "${miniconda_sha256} miniconda.sh" > anaconda.sha256 && \
    sha256sum --strict -c anaconda.sha256 && \
    bash miniconda.sh -b -p /opt/conda && \
    export PATH=/opt/conda/bin:$PATH && \
    conda config --set always_yes yes --set changeps1 no && \
    conda info -a && \
    conda install mamba -c conda-forge && \
    mamba env update -f /env_python_3_with_R.yml --prune && \
    # Cleanup
    rm -v miniconda.sh anaconda.sha256  && \
    # Cleanup based on https://github.com/ContinuumIO/docker-images/commit/cac3352bf21a26fa0b97925b578fb24a0fe8c383
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    mamba clean -ay
    # Allow to modify conda packages. This allows malicious code to be injected into other interpreter sessions, therefore it is disabled by default
    # chmod -R ug+rwX /opt/conda
ENV PATH /opt/conda/envs/python_3_with_R/bin:/opt/conda/bin:$PATH

RUN echo "$LOG_TAG Download Zeppelin binary" && \
    mkdir -p ${ZEPPELIN_HOME} && \
    chown -R root:root ${ZEPPELIN_HOME} && \
    mkdir -p ${ZEPPELIN_HOME}/logs ${ZEPPELIN_HOME}/run ${ZEPPELIN_HOME}/webapps && \
    # Allow process to edit /etc/passwd, to create a user entry for zeppelin
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    # Give access to some specific folders
    chmod -R 775 "${ZEPPELIN_HOME}/logs" "${ZEPPELIN_HOME}/run" "${ZEPPELIN_HOME}/notebook" "${ZEPPELIN_HOME}/conf" && \
    # Allow process to create new folders (e.g. webapps)
    chmod 775 ${ZEPPELIN_HOME} && \
    chmod -R 775 /opt/conda

COPY /scripts/docker/zeppelin/bin/log4j.properties ${ZEPPELIN_HOME}/conf/
COPY /scripts/docker/zeppelin/bin/log4j_docker.properties ${ZEPPELIN_HOME}/conf/
COPY /scripts/docker/zeppelin/bin/log4j2.properties ${ZEPPELIN_HOME}/conf/
COPY /scripts/docker/zeppelin/bin/log4j2_docker.properties ${ZEPPELIN_HOME}/conf/

USER 1000

EXPOSE 8080

ENTRYPOINT [ "/usr/bin/tini", "--" ]
WORKDIR ${ZEPPELIN_HOME}
CMD ["bin/zeppelin.sh"]
