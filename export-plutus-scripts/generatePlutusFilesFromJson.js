// This script reads scripts.json and generates a .plutus file for each unique script_name -> category -> value.
// It uses the "cbor" property as the value for "cborHex" in the output file.

const fs = require("fs");
const path = require("path");

const scripts = require("./scripts.json");
const outputDir = path.join(process.cwd(), "./plutus-scripts");
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir);
}

for (const scriptName of Object.keys(scripts)) {
  const categories = scripts[scriptName];
  for (const category of Object.keys(categories)) {
    const value = categories[category];
    // Use value.cbor for cborHex if available, otherwise fallback to value.hash or value
    const cborHex =
      value && value.cbor
        ? value.cbor
        : value && value.hash
        ? value.hash
        : value;
    const fileName = `${scriptName}_${category}.plutus`;
    const filePath = path.join(outputDir, fileName);

    const jsonContent = {
      type: "PlutusScriptV3",
      description: `${scriptName} ${category}`,
      cborHex: cborHex,
    };

    fs.writeFileSync(filePath, JSON.stringify(jsonContent, null, 2));
  }
}

console.log("Plutus scripts exported to", outputDir);
