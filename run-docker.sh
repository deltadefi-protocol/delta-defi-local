#!/usr/bin/env bash
#
# Prepare environment to run the demo cluster, then launches docker compose
# demo. If there's already a demo running, bail out.
set -e

SCRIPT_DIR=$(dirname $(realpath $0))

DOCKER_COMPOSE_CMD=
if docker compose --version > /dev/null 2>&1; then
  DOCKER_COMPOSE_CMD="docker compose"
else
  DOCKER_COMPOSE_CMD="docker-compose"
fi

# Sanity check to prevent accidentally tripping oneself with an existing demo
if ( ${DOCKER_COMPOSE_CMD} ps | grep hydra-node > /dev/null 2>&1 ); then
  echo >&2 -e "# Demo already in progress, exiting"
  echo >&2 -e "# To stop the demo use: ${DOCKER_COMPOSE_CMD} down"
  exit 1
fi

"${SCRIPT_DIR}/prepare-devnet.sh"
sleep 3
${DOCKER_COMPOSE_CMD} up -d postgres
${DOCKER_COMPOSE_CMD} up -d redis
${DOCKER_COMPOSE_CMD} up -d questdb
${DOCKER_COMPOSE_CMD} up -d cardano-node
${DOCKER_COMPOSE_CMD} up -d kupo
${DOCKER_COMPOSE_CMD} up -d ogmios
"${SCRIPT_DIR}/seed-devnet.sh"
${DOCKER_COMPOSE_CMD} up -d hydra-node-{1,2,3,4}
echo >&2 -e "\n# Launch TUI on hydra-node-1: ${DOCKER_COMPOSE_CMD} run hydra-tui-1"
echo >&2 -e "\n# Stop the demo: ${DOCKER_COMPOSE_CMD} down\n"
# ${DOCKER_COMPOSE_CMD} build --no-cache belvederex
${DOCKER_COMPOSE_CMD} up --build -d belvedere
${DOCKER_COMPOSE_CMD} up -d orderbook
${DOCKER_COMPOSE_CMD} up -d valve
${DOCKER_COMPOSE_CMD} up -d hibiki
${DOCKER_COMPOSE_CMD} up -d tonic
${DOCKER_COMPOSE_CMD} up -d espresso-api
${DOCKER_COMPOSE_CMD} up -d espresso-worker

${DOCKER_COMPOSE_CMD} run hydra-tui-1
