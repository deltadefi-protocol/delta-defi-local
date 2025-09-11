// This script exports the scripts object from constant.ts to a JSON file for use in Node.js.
import { scripts } from "../belvedere/backend/mesh/src/lib/constant";
import * as fs from "fs";
import * as path from "path";

const outputPath = path.join(process.cwd(), "scripts.json");
fs.writeFileSync(outputPath, JSON.stringify(scripts, null, 2));
console.log("scripts object exported to", outputPath);
