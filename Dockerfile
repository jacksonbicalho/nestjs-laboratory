ARG DOCKER_WORK_DIR_DEFAULT=/usr/src/app

#############################
# base: build for Base
#############################
FROM node:18.15.0-alpine As base
ARG DOCKER_LABEL_KEY
ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}
LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ONBUILD ENV YARN_VERSION 1.22.19

ONBUILD ARG NODE_ENV
ONBUILD ENV NODE_ENV ${NODE_ENV:-builder}

ONBUILD ARG DOCKER_USER_UID
ONBUILD ENV DOCKER_USER_UID ${DOCKER_USER_UID:-36891}

ONBUILD ARG USER_NAME=${NODE_ENV}
ONBUILD ENV USER_NAME ${USER_NAME:-criador}

ONBUILD ARG DOCKER_WORK_DIR
ONBUILD ENV DOCKER_WORK_DIR ${DOCKER_WORK_DIR:-$DOCKER_WORK_DIR_DEFAULT}

ONBUILD COPY \
  package.json* \
  yarn.lock* \
  .yarnrc* \
  .npmrc* \
  npm-shrinkwrap.json* \
  package-lock.json* \
  pnpm-lock.yaml* ./

ONBUILD RUN rm -rf /usr/local/bin/yarn \
  && rm -rf /usr/local/bin/yarnpkg \
  && npm uninstall --loglevel warn --global pnpm \
  && npm uninstall --loglevel warn --global npm \
  && deluser --remove-home node \
  && addgroup -S ${USER_NAME} -g ${DOCKER_USER_UID} \
  && adduser -S -G ${USER_NAME} -u ${DOCKER_USER_UID} ${USER_NAME} \
  && apk --no-cache update \
  && apk add --no-cache \
  make \
  python3 \
  bash \
  curl \
  --virtual builds-deps \
  && apk add git \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -snf /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -snf /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz \
  && yarn --version \
  && curl -sfL RUN curl -sf https://gobinaries.com/tj/node-prune | bash -s -- -b /usr/local/bin/ \
  && apk del builds-deps \
  && rm -rf /var/cache/apk/* \
  && yarn global add @nestjs/cli

ONBUILD WORKDIR ${DOCKER_WORK_DIR}

ONBUILD COPY . ./

ONBUILD RUN ls -l \
  && yarn \
  && ls /usr/local/bin/ \
  && /usr/local/bin/node-prune \
  && chown -R ${USER_NAME}:${USER_NAME} ./

ONBUILD USER ${USER_NAME}


#####################################
# development: build for development
#####################################
FROM base as development
ARG DOCKER_LABEL_KEY
ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}
LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

# RUN git config --global user.email "jacksonbicalho@gmail.com" \
#   && git config --global user.name "Jackson Bicalho"

ENV NODE_ENV=development

ARG SERVER_PORT
ENV SERVER_PORT ${SERVER_PORT:-3000}

EXPOSE ${SERVER_PORT}

CMD ["yarn", "start:dev"]


##########################################
# builder-prod: pre bulder for production
##########################################
FROM node:18.15.0-alpine as builder-prod
ARG DOCKER_LABEL_KEY
ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}
LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ARG DOCKER_WORK_DIR
ENV DOCKER_WORK_DIR ${DOCKER_WORK_DIR:-$DOCKER_WORK_DIR_DEFAULT}

WORKDIR ${DOCKER_WORK_DIR}

COPY ./package.json ./yarn.lock ./tsconfig.json ./

# See: https://github.com/yarnpkg/yarn/issues/6312
RUN yarn --skip-integrity-check --network-concurrency 1

COPY . .

RUN yarn build


######################################
# production: builder form production
######################################
FROM node:18.15.0-alpine as production
ARG DOCKER_LABEL_KEY
ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}
LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ARG NODE_ENV=production
ENV NODE_ENV ${NODE_ENV}

ENV USER_NAME ${NODE_ENV}

RUN deluser --remove-home node \
  # Get a random UID/GID from 10,000 to 65,532
  && while [ "${ID:-0}" -lt "10000" ] || [ "${ID:-99999}" -ge "65533" ]; do \
  ID=$(od -An -tu -N2 /dev/urandom | tr -d " "); \
  done \
  && addgroup -S ${USER_NAME} -g ${ID} \
  && adduser -S -G ${USER_NAME} -u ${ID} ${USER_NAME} >/dev/null

ARG DOCKER_WORK_DIR
ENV DOCKER_WORK_DIR ${DOCKER_WORK_DIR:-$DOCKER_WORK_DIR_DEFAULT}

WORKDIR ${DOCKER_WORK_DIR}

COPY --chown=${USER_NAME}:${USER_NAME} --from=builder-prod ${DOCKER_WORK_DIR} ./

USER ${USER_NAME}

ARG SERVER_PORT
ENV SERVER_PORT ${SERVER_PORT:-3000}
EXPOSE ${SERVER_PORT}

CMD [ "yarn", "start:prod" ]


######################################
# testing: builder form tests
######################################
FROM development as testing
ARG DOCKER_LABEL_KEY
ARG DOCKER_LABEL_VALUE
ENV DOCKER_LABEL_KEY ${DOCKER_LABEL_KEY}
ENV DOCKER_LABEL_VALUE ${DOCKER_LABEL_VALUE}
LABEL ${DOCKER_LABEL_KEY}=${DOCKER_LABEL_VALUE}

ENV CI=true
CMD ["yarn","test:cov"]
