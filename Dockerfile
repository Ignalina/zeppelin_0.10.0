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
RUN export ZEPPELIN_HOME=/opt/zeppelin
RUN |2 miniconda_version=py37_4.9.2 miniconda_sha256=79510c6e7bd9e012856e25dcb21b3e093aa4ac8113d9aa7e82a86987eabe1c31 /bin/sh -c echo "$LOG_TAG Zeppelin binary"  &&   rm -f /tmp/zeppelin-${Z_VERSION}-bin-all.tgz &&     chown -R root:root ${ZEPPELIN_HOME} &&     mkdir -p ${ZEPPELIN_HOME}/logs ${ZEPPELIN_HOME}/run ${ZEPPELIN_HOME}/webapps &&     chgrp root /etc/passwd && chmod ug+rw /etc/passwd &&     chmod -R 775 "${ZEPPELIN_HOME}/logs" "${ZEPPELIN_HOME}/run" "${ZEPPELIN_HOME}/notebook" "${ZEPPELIN_HOME}/conf" &&     chmod 775 ${ZEPPELIN_HOME} &&     chmod -R 775 /opt/conda 

ENTRYPOINT ["/usr/bin/tini" "--"]
WORKDIR /opt/zeppelin
CMD ["bin/zeppelin.sh"]
