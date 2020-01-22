FROM debian:buster-slim

COPY . /app

ENV COMPILER_PATH=/app/compiler/addons/sourcemod/scripting

WORKDIR /app

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
    ca-certificates \
    curl \
    lib32stdc++6

# SourceMod
RUN mkdir compiler \
    && SMVERSION=$(curl -s https://sm.alliedmods.net/smdrop/1.11/sourcemod-latest-linux) \
    && echo $SMVERSION \
    && curl -s https://sm.alliedmods.net/smdrop/1.11/$SMVERSION | tar zxf - -C compiler/ \
    && chmod +x $COMPILER_PATH/spcomp

# Dependency: Multicolors
RUN mkdir dependency \
    && cd dependency \
    && git clone https://github.com/Bara/Multi-Colors.git . \
    && rsync -av addons/sourcemod/scripting/include/ $COMPILER_PATH/include/ \
    && rm -rf dependency

# Compile Plugin
RUN cd addons/sourcemod/scripting/ \
    && $COMPILER_PATH/spcomp 1v100.sp