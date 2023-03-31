FROM openjdk:8 as build-env

ENV SBT_VERSION "1.5.8"

RUN apt-get update \
  && apt-get install -y apt-transport-https \
  && apt-get install -y nodejs \
			npm \
                        git \
                        libpng-dev \
                        sudo \
                        \
  && npm install -g grunt-cli \
                    bower \
  && apt-get update

RUN \
  mkdir /working/ && \
  cd /working/ && \
  curl -L -o sbt-$SBT_VERSION.deb https://repo.scala-sbt.org/scalasbt/debian/sbt-$SBT_VERSION.deb && \
  dpkg -i sbt-$SBT_VERSION.deb && \
  rm sbt-$SBT_VERSION.deb && \
  apt-get update && \
  apt-get install sbt && \
  cd && \
  rm -r /working/ && \
  sbt sbtVersion

RUN mkdir Cortex

COPY . Cortex/

WORKDIR Cortex

RUN sbt stage
#-Dsbt.rootdir=true
  #&& /opt/4.1.14/sbt clean stage \
  
  
RUN mv ./target/universal/stage /opt/cortex \
  && mv ./package/docker/entrypoint /opt/cortex/entrypoint \
  && echo "play.http.secret.key=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 49)" >> /opt/cortex/conf/application.conf \
  && mkdir /var/log/cortex \
  && apt-get purge -y git \
                      nodejs \
                      libpng-dev \
  && rm -rf /Cortex \
            /root/* \
            /root/.m2 \
            /root/.ivy2 \
            /root/.sbt \
            /var/lib/apt/lists/*

FROM openjdk:8
COPY --from=build-env /opt/cortex /opt/cortex
COPY --from=build-env /var/log/cortex /var/log/cortex

RUN useradd cortex \
  && chown -R cortex /opt/cortex \
                      /var/log/cortex \
  && mkdir /etc/cortex \
  && cp /opt/cortex/conf/application.sample /etc/cortex/application.conf \
  && cp /opt/cortex/conf/logback.xml /etc/cortex/logback.xml \
  && echo 'search.host = ["http://elasticsearch-master.elasticsearch:9200"]\n\
play.http.secret.key = ${?PLAY_SECRET}' >> /etc/cortex/application.conf \
  && chmod +x /opt/cortex/entrypoint

USER cortex

EXPOSE 9001

RUN chmod -R 777 /opt/cortex

RUN chmod -R 777 /var/log/cortex

WORKDIR /opt/cortex

ENTRYPOINT ["./entrypoint"]
