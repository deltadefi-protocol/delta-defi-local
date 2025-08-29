#!/usr/bin/env bash

# Seed a "devnet" by distributing Ada to hydra nodes
set -eo pipefail

# See: https://github.com/cardano-scaling/hydra/pull/1682
[[ $(jq -n '9223372036854775807') == "9223372036854775807" ]] \
  || (echo "bad jq roundtrip: please upgrade your jq to version 1.7+"; exit 1)

SCRIPT_DIR=${SCRIPT_DIR:-$(realpath $(dirname $(realpath $0)))}
NETWORK_ID=42

CCLI_CMD=
DEVNET_DIR=devnet
if [[ -n ${1} ]]; then
    echo >&2 "Using provided cardano-cli command: ${1}"
    $(${1} version > /dev/null)
    CCLI_CMD=${1}
    DEVNET_DIR=devnet
fi

HYDRA_NODE_CMD=
if [[ -n ${2} ]]; then
    echo >&2 "Using provided hydra-node command: ${2}"
    ${2} --version > /dev/null
    HYDRA_NODE_CMD=${2}
fi

DOCKER_COMPOSE_CMD=
if [[ ! -x ${CCLI_CMD} ]]; then
  if docker compose --version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
  else
    DOCKER_COMPOSE_CMD="docker-compose"
  fi
fi

# Invoke cardano-cli in running cardano-node container or via provided cardano-cli
function ccli() {
  ccli_ ${@} --testnet-magic ${NETWORK_ID}
}
function ccli_() {
  if [[ -x ${CCLI_CMD} ]]; then
      ${CCLI_CMD} ${@}
  else
      ${DOCKER_COMPOSE_CMD} exec cardano-node cardano-cli ${@}
  fi
}

# Invoke hydra-node in a container or via provided executable
function hnode() {
  if [[ -n ${HYDRA_NODE_CMD} ]]; then
      ${HYDRA_NODE_CMD} ${@}
  else
      docker run --rm -it \
        --pull always \
        -v ${SCRIPT_DIR}/devnet:/devnet \
        ghcr.io/cardano-scaling/hydra-node:0.22.2 -- ${@}
  fi
}

# Retrieve some lovelace from faucet
function seedFaucet() {
    ACTOR=${1}
    AMOUNT=${2}
    echo >&2 "Seeding a UTXO from faucet to ${ACTOR} with ${AMOUNT}Ł"

    # Determine faucet address and just the **first** txin addressed to it
    FAUCET_ADDR=$(ccli conway address build --payment-verification-key-file ${DEVNET_DIR}/credentials/faucet.vk)
    FAUCET_TXIN=$(ccli conway query utxo --address ${FAUCET_ADDR} --out-file /dev/stdout | jq -r 'keys[0]')

    ACTOR_ADDR=$(ccli conway address build --payment-verification-key-file ${DEVNET_DIR}/credentials/${ACTOR}.vk)

    ccli conway transaction build --cardano-mode \
        --change-address ${FAUCET_ADDR} \
        --tx-in ${FAUCET_TXIN} \
        --tx-out ${ACTOR_ADDR}+${AMOUNT} \
        --out-file ${DEVNET_DIR}/seed-${ACTOR}.draft >&2
    ccli conway transaction sign \
        --tx-body-file ${DEVNET_DIR}/seed-${ACTOR}.draft \
        --signing-key-file ${DEVNET_DIR}/credentials/faucet.sk \
        --out-file ${DEVNET_DIR}/seed-${ACTOR}.signed >&2
    SEED_TXID=$(ccli_ conway transaction txid --tx-file ${DEVNET_DIR}/seed-${ACTOR}.signed | tr -d '\r')
    SEED_TXIN="${SEED_TXID}#0"
    ccli conway transaction submit --tx-file ${DEVNET_DIR}/seed-${ACTOR}.signed >&2

    echo -n >&2 "Waiting for utxo ${SEED_TXIN}.."

    while [[ "$(ccli query utxo --tx-in "${SEED_TXIN}" --out-file /dev/stdout | jq ".\"${SEED_TXIN}\"")" = "null" ]]; do
        sleep 1
        echo -n >&2 "."
    done
    echo >&2 "Done"
}

function seedFaucetAddress() {
    ADDRESS=${1}
    AMOUNT=${2}
    echo >&2 "Seeding a UTXO from faucet to ${ADDRESS} with ${AMOUNT}Ł"

    FAUCET_ADDR=$(ccli conway address build --payment-verification-key-file ${DEVNET_DIR}/credentials/faucet.vk)
    FAUCET_TXIN=$(ccli conway query utxo --address ${FAUCET_ADDR} --out-file /dev/stdout | jq -r 'keys[0]')

    ccli conway transaction build --cardano-mode \
        --change-address ${FAUCET_ADDR} \
        --tx-in ${FAUCET_TXIN} \
        --tx-out ${ADDRESS}+${AMOUNT} \
        --out-file ${DEVNET_DIR}/seed-${ADDRESS}.draft >&2
    ccli conway transaction sign \
        --tx-body-file ${DEVNET_DIR}/seed-${ADDRESS}.draft \
        --signing-key-file ${DEVNET_DIR}/credentials/faucet.sk \
        --out-file ${DEVNET_DIR}/seed-${ADDRESS}.signed >&2

    SEED_TXID=$(ccli_ conway transaction txid --tx-file ${DEVNET_DIR}/seed-${ADDRESS}.signed | tr -d '\r')
    SEED_TXIN="${SEED_TXID}#0"
    echo -n >&2 "Submitting transaction ${SEED_TXID}.."
    ccli conway transaction submit --tx-file ${DEVNET_DIR}/seed-${ADDRESS}.signed >&2

    echo -n >&2 "Waiting for utxo ${SEED_TXIN}.."

    while [[ "$(ccli query utxo --tx-in "${SEED_TXIN}" --out-file /dev/stdout | jq ".\"${SEED_TXIN}\"")" = "null" ]]; do
        sleep 1
        echo -n >&2 "."
    done
    echo >&2 "Done"
}

function publishReferenceScripts() {
  echo >&2 "Publishing reference scripts..."
  hnode publish-scripts \
    --testnet-magic ${NETWORK_ID} \
    --node-socket ${DEVNET_DIR}/node.socket \
    --cardano-signing-key devnet/credentials/faucet.sk
}

function publishDDReferenceScripts() {
  echo >&2 "Publishing DD reference scripts..."
  ADDR=${1}
  AMOUNT=${2}
  SCRIPT_PATH=${3}
  NAME=${4}
  # Determine faucet address and just the **first** txin addressed to it
  FAUCET_ADDR=$(ccli conway address build --payment-verification-key-file ${DEVNET_DIR}/credentials/faucet.vk)
  FAUCET_TXIN=$(ccli conway query utxo --address ${FAUCET_ADDR} --out-file /dev/stdout | jq -r 'keys[0]')

  ccli conway transaction build --cardano-mode \
        --change-address ${FAUCET_ADDR} \
        --tx-in ${FAUCET_TXIN} \
        --tx-out ${ADDR}+${AMOUNT} \
        --tx-out-reference-script-file ${SCRIPT_PATH} \
        --out-file ${DEVNET_DIR}/seed-ref-${NAME}.draft >&2
    ccli conway transaction sign \
        --tx-body-file ${DEVNET_DIR}/seed-ref-${NAME}.draft \
        --signing-key-file ${DEVNET_DIR}/credentials/faucet.sk \
        --out-file ${DEVNET_DIR}/seed-ref-${NAME}.signed >&2

    echo -n >&2 "Submitting transaction to create ref script ${NAME}.."
    ccli conway transaction submit --tx-file ${DEVNET_DIR}/seed-ref-${NAME}.signed >&2
}

publishDDReferenceScripts "addr_test1qpsjnpqljma4vdg67vtf8k4xv7umncum5lvrnlupfyyvmtawhmy5tqhkqm4lrwwm6wkykzsa2aafy25vevxhrc3fws0qszw7wl" 60000000 "./plutus-scripts/accountOperation_appDeposit.plutus" "appDeposit"

# echo >&2 "Fueling up hydra nodes of alice, bob, charlie, david..."
# seedFaucet "alice-node" 30000000 # 30 Ada to the node
# seedFaucet "bob-node" 30000000 # 30 Ada to the node
# seedFaucet "charlie-node" 30000000 # 30 Ada to the node
# seedFaucet "david-node" 30000000 # 30 Ada to the node

# echo >&2 "Distributing funds to alice, bob, charlie, david..."
# seedFaucet "alice-funds" 100000000 # 100 Ada to commit
# seedFaucet "bob-funds" 50000000 # 50 Ada to commit
# seedFaucet "charlie-funds" 25000000 # 25 Ada to commit
# seedFaucet "david-funds" 30000000 # 30 Ada to commit

# echo >&2 "Distributing funds to DeltaDefi specific accounts..."
# seedFaucetAddress "addr_test1qra9zdhfa8kteyr3mfe7adkf5nlh8jl5xcg9e7pcp5w9yhyf5tek6vpnha97yd5yw9pezm3wyd77fyrfs3ynftyg7njs5cfz2x" 5000000000 # 5000 ADA to DeltaDefi Trade account
# seedFaucetAddress "addr_test1qqzgg5pcaeyea69uptl9da5g7fajm4m0yvxndx9f4lxpkehqgezy0s04rtdwlc0tlvxafpdrfxnsg7ww68ge3j7l0lnszsw2wt" 5000000000 # 5000 ADA to DeltaDefi Summer account
# seedFaucetAddress "addr_test1qqzgg5pcaeyea69uptl9da5g7fajm4m0yvxndx9f4lxpkehqgezy0s04rtdwlc0tlvxafpdrfxnsg7ww68ge3j7l0lnszsw2wt" 5000000 # 5 ADA to DeltaDefi Summer account for collateral
# seedFaucetAddress "addr_test1qra9zdhfa8kteyr3mfe7adkf5nlh8jl5xcg9e7pcp5w9yhyf5tek6vpnha97yd5yw9pezm3wyd77fyrfs3ynftyg7njs5cfz2x" 5000000 # 5 ADA to DeltaDefi Trade account for app_oracle
# seedFaucetAddress "addr_test1qra9zdhfa8kteyr3mfe7adkf5nlh8jl5xcg9e7pcp5w9yhyf5tek6vpnha97yd5yw9pezm3wyd77fyrfs3ynftyg7njs5cfz2x" 5000000 # 5 ADA to DeltaDefi Trade account for dex_oracle
# seedFaucetAddress "addr_test1qqzgg5pcaeyea69uptl9da5g7fajm4m0yvxndx9f4lxpkehqgezy0s04rtdwlc0tlvxafpdrfxnsg7ww68ge3j7l0lnszsw2wt" 5000000 # 5 ADA to DeltaDefi Summer account for setup
# seedFaucetAddress "addr_test1qqzgg5pcaeyea69uptl9da5g7fajm4m0yvxndx9f4lxpkehqgezy0s04rtdwlc0tlvxafpdrfxnsg7ww68ge3j7l0lnszsw2wt" 5000000 # 5 ADA to DeltaDefi Summer account for setup
# seedFaucetAddress "addr_test1qqzgg5pcaeyea69uptl9da5g7fajm4m0yvxndx9f4lxpkehqgezy0s04rtdwlc0tlvxafpdrfxnsg7ww68ge3j7l0lnszsw2wt" 5000000 # 5 ADA to DeltaDefi Summer account for setup


# # Replace the existing .env handling code at the end of the file
# # Create or update .env file
# if [ -f .env ]; then
#   # If .env exists, update or add HYDRA_SCRIPTS_TX_ID while preserving other variables
#   SCRIPTS_TX_ID=$(publishReferenceScripts)
#   if grep -q "HYDRA_SCRIPTS_TX_ID=" .env; then
#     # Replace existing HYDRA_SCRIPTS_TX_ID
#     sed -i '' "s/HYDRA_SCRIPTS_TX_ID=.*/HYDRA_SCRIPTS_TX_ID=${SCRIPTS_TX_ID}/" .env
#   else
#     # Add HYDRA_SCRIPTS_TX_ID as a new line
#     echo "HYDRA_SCRIPTS_TX_ID=${SCRIPTS_TX_ID}" >> .env
#   fi
# else
#   # Create a new .env file with just the HYDRA_SCRIPTS_TX_ID
#   echo "HYDRA_SCRIPTS_TX_ID=$(publishReferenceScripts)" > .env
# fi

# echo >&2 "Environment variable updated in '.env'"
# echo >&2 -e "\n\t$(grep HYDRA_SCRIPTS_TX_ID .env)\n"