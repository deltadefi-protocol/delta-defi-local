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