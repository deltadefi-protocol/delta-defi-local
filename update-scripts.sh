#!/bin/bash

cd belvedere/aiken-workspace
aiken build -t verbose

cd ../../export-plutus-scripts
tsx exportScriptsToJson.ts
node generatePlutusFilesFromJson.js

cd ..
rm -rf ./devnet-config/plutus-scripts
cp -r ./export-plutus-scripts/plutus-scripts ./devnet-config/plutus-scripts
echo "Plutus scripts updated in devnet-config/plutus-scripts"

SCRIPTS_JSON="./export-plutus-scripts/scripts.json"
ENV_FILE="./env/.script-hash.env"

jq -r '
  "APP_ORACLE_ADDRESS=\"" + .appOracle.spend.address + "\"",
  "APP_VAULT_ADDRESS=\"" + .appVault.spend.address + "\"",
  "APP_DEPOSIT_REQUEST_ADDRESS=\"" + .appDepositRequest.spend.address + "\"",
  "DEX_NET_DEPOSIT_ADDRESS=\"" + .dexNetDeposit.spend.address + "\"",
  "DEX_ACCOUNT_BALANCE_ADDRESS=\"" + .dexAccountBalance.spend.address + "\"",
  "DEX_ORDER_BOOK_ADDRESS=\"" + .dexOrderBook.spend.address + "\"",
  "HYDRA_USER_INTENT_ADDRESS=\"" + .hydraUserIntent.spend.address + "\"",
  "HYDRA_ACCOUNT_BALANCE_ADDRESS=\"" + .hydraAccountBalance.spend.address + "\"",
  "HYDRA_ORDER_BOOK_ADDRESS=\"" + .hydraOrderBook.spend.address + "\"",
  "APP_DEPOSIT_TOKEN_SCRIPT_HASH=\"" + .appDepositRequest.mint.hash + "\"",
  "DEX_NET_DEPOSIT_TOKEN_SCRIPT_HASH=\"" + .dexNetDeposit.mint.hash + "\"",
  "DEX_ACCOUNT_BALANCE_TOKEN_SCRIPT_HASH=\"" + .dexAccountBalance.mint.hash + "\"",
  "DEX_ORDER_BOOK_TOKEN_SCRIPT_HASH=\"" + .dexOrderBook.mint.hash + "\"",
  "HYDRA_ACCOUNT_BALANCE_TOKEN_SCRIPT_HASH=\"" + .hydraAccountBalance.mint.hash + "\"",
  "HYDRA_ORDER_BOOK_TOKEN_SCRIPT_HASH=\"" + .hydraOrderBook.mint.hash + "\"",
  "HYDRA_USER_INTENT_TOKEN_SCRIPT_HASH=\"" + .hydraUserIntent.mint.hash + "\""
' "$SCRIPTS_JSON" > "$ENV_FILE"