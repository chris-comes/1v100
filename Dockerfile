FROM debian:buster-slim

ENV COMPILER_PATH=/tmp/app/addons/sourcemod/scripting

WORKDIR /app

COPY . /app

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    git \
    lib32stdc++6 \
    mercurial \
    rsync

# SourceMod
RUN mkdir app \
    && SMVERSION=$(curl -s https://sm.alliedmods.net/smdrop/1.10/sourcemod-latest-linux) \
    && echo $SMVERSION \
    && curl -s https://sm.alliedmods.net/smdrop/1.10/$SMVERSION | tar zxf - -C app/ \
    && chmod +x $COMPILER_PATH/spcomp

# 1v100 Plugin
RUN $COMPILER_PATH/spcomp 1v100.sp