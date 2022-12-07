# ------------------------------------------------------------------------
#
# Copyright 2019 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
#
# ------------------------------------------------------------------------

# set base Docker image to Alpine Docker image
FROM alpine:3.15

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# install JDK Dependencies
RUN apk add --no-cache tzdata musl-locales musl-locales-lang \
    && rm -rf /var/cache/apk/*

ENV JAVA_VERSION jdk-11.0.14+9
# install OpenJDK 11
RUN set -eux; \
    ARCH="$(apk --print-arch)"; \
    case "${ARCH}" in \
       amd64|x86_64) \
         ESUM='f94a01258a5496eda9e3de6807e6ecfe08a5ad4a2d42e4332a77f74174706f5c'; \
         BINARY_URL='https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.14%2B9/OpenJDK11U-jdk_x64_alpine-linux_hotspot_11.0.14_9.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
    esac; \
      wget -O /tmp/openjdk.tar.gz ${BINARY_URL}; \
	  echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
	  mkdir -p /opt/java/openjdk; \
	  tar --extract \
	      --file /tmp/openjdk.tar.gz \
	      --directory /opt/java/openjdk \
	      --strip-components 1 \
	      --no-same-owner \
	  ; \
    rm -rf /tmp/openjdk.tar.gz;

ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH"

#Copy the product pack
# COPY wso2mi-4.1.0.zip ${WSO2_SERVER}.zip

# Verify Java installation
RUN echo Verifying install ... \
    && echo javac --version && javac --version \
    && echo java --version && java --version \
    && echo Complete.

LABEL maintainer="WSO2 Docker Maintainers <dev@wso2.org>" \
      com.wso2.docker.source="https://github.com/wso2/docker-ei/releases/tag/v4.1.0.1"

# set Docker image build arguments
# build arguments for user/group configurations
ARG USER=wso2carbon
ARG USER_ID=10001
ARG USER_GROUP=wso2
ARG USER_GROUP_ID=10001
ARG USER_HOME=/home/${USER}
# build arguments for WSO2 product installation
ARG WSO2_SERVER_NAME=wso2mi
ARG WSO2_SERVER_VERSION=4.2.0-SNAPSHOT
ARG WSO2_SERVER_REPOSITORY=micro-integrator
ARG WSO2_SERVER=${WSO2_SERVER_NAME}-${WSO2_SERVER_VERSION}
ARG WSO2_SERVER_HOME=${USER_HOME}/${WSO2_SERVER}
ARG WSO2_SERVER_DIST_URL=https://github.com/wso2/${WSO2_SERVER_REPOSITORY}/releases/download/v${WSO2_SERVER_VERSION}/${WSO2_SERVER}.zip
ARG WSO2_MI_URL=https://github.com/arunans23/HelloGreetings/releases/download/1.6.0/wso2mi-4.2.0-SNAPSHOT.zip
# build argument for MOTD
ARG MOTD='printf "\n\
 Welcome to WSO2 Docker Resources \n\
 --------------------------------- \n\
 This Docker container comprises of a WSO2 product, running with its latest GA release \n\
 which is under the Apache License, Version 2.0. \n\
 Read more about Apache License, Version 2.0 here @ http://www.apache.org/licenses/LICENSE-2.0.\n"'
ENV ENV=${USER_HOME}"/.ashrc"

# create the non-root user and group and set MOTD login message
RUN \
    addgroup -S -g ${USER_GROUP_ID} ${USER_GROUP} \
    && adduser -S -u ${USER_ID} -h ${USER_HOME} -G ${USER_GROUP} ${USER} \
    && echo ${MOTD} > "${ENV}"

# copy init script to user home
COPY --chown=wso2carbon:wso2 docker-entrypoint.sh ${USER_HOME}/
# install required packages
RUN apk add --no-cache netcat-openbsd
# add the WSO2 product distribution to user's home directory
RUN \
    wget -O ${WSO2_SERVER}.zip "${WSO2_MI_URL}" \
    && unzip -d ${USER_HOME} ${WSO2_SERVER}.zip \
    && rm -f ${WSO2_SERVER}.zip \
    && chown wso2carbon:wso2 -R ${WSO2_SERVER_HOME}

RUN mkdir /home/wso2carbon/wso2mi-4.2.0-SNAPSHOT/repository/deployment/server/synapse-configs/default/api

ARG CAR_URL
ARG CAR_NAME=HelloWorldGreetingsCompositeExporter_1.0.0-SNAPSHOT

RUN wget ${CAR_URL}

RUN cp ${CAR_NAME}.car /home/wso2carbon/wso2mi-4.2.0-SNAPSHOT/repository/deployment/server/carbonapps/

#Copy the artifacts in to carbon home
# COPY HelloWorld.xml /home/wso2carbon/wso2mi-4.2.0-SNAPSHOT/repository/deployment/server/synapse-configs/default/api/HelloWorld.xml

#COPY HelloWorldGreetingsCompositeExporter_1.0.0-SNAPSHOT.car /home/wso2carbon/wso2mi-4.2.0-SNAPSHOT/repository/deployment/server/carbonapps/HelloWorldGreetingsCompositeExporter_1.0.0-SNAPSHOT.car
COPY EmailTestProjectCompositeExporter_1.0.0-SNAPSHOT.car /home/wso2carbon/wso2mi-4.2.0-SNAPSHOT/repository/deployment/server/carbonapps/EmailTestProjectCompositeExporter_1.0.0-SNAPSHOT.car
# COPY GoogleCalendarEventsToEmailCompositeExporter_1.0.0-SNAPSHOT.car /home/wso2carbon/wso2mi-4.2.0-SNAPSHOT/repository/deployment/server/carbonapps/GoogleCalendarEventsToEmailCompositeExporter_1.0.0-SNAPSHOT.car

RUN ${WSO2_SERVER_HOME}/bin/extension-runner.sh

# set the user and work directory
USER ${USER_ID}
WORKDIR ${USER_HOME}

# set environment variables
ENV WORKING_DIRECTORY=${USER_HOME} \
    WSO2_SERVER_HOME=${WSO2_SERVER_HOME}

# expose server ports
EXPOSE 8253 8290

USER 10001

# initiate container and start WSO2 Carbon server
ENTRYPOINT ["/home/wso2carbon/docker-entrypoint.sh"]
