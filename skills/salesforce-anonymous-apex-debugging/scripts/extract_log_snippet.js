#!/usr/bin/env node

/**
 * Extract a focused snippet from a Salesforce debug log.
 *
 * Usage:
 *   node extract_log_snippet.js --log /path/to/log.txt --token MYBUG --context 80
 *
 * What it does:
 *   - Prints lines around the first occurrence of the token.
 *   - Also prints the first occurrence of EXCEPTION_THROWN or FATAL_ERROR if present.
 *
 * Notes:
 *   - This is a convenience tool for humans and agents.
 *   - It does not parse log structure beyond simple string matching.
 */

const fs = require("node:fs");

function parseArgs(argv) {
  const args = { context: 80 };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--log") {
      args.log = argv[i + 1];
      i += 1;
    } else if (arg === "--token") {
      args.token = argv[i + 1];
      i += 1;
    } else if (arg === "--context") {
      const parsed = Number.parseInt(argv[i + 1], 10);
      if (Number.isNaN(parsed) || parsed < 0) {
        throw new Error("--context must be a non-negative integer");
      }
      args.context = parsed;
      i += 1;
    } else if (arg === "--help" || arg === "-h") {
      printUsageAndExit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!args.log || !args.token) {
    printUsageAndExit(1);
  }

  return args;
}

function printUsageAndExit(code) {
  const usage = [
    "Usage:",
    "  node extract_log_snippet.js --log /path/to/log.txt --token MYBUG --context 80",
    "",
    "Required arguments:",
    "  --log      Path to the debug log text file",
    "  --token    Token to locate, example: MYBUG",
    "",
    "Optional arguments:",
    "  --context  Lines before and after the match (default: 80)",
  ].join("\n");
  process.stdout.write(`${usage}\n`);
  process.exit(code);
}

function findFirstIndex(lines, needle) {
  for (let i = 0; i < lines.length; i += 1) {
    if (lines[i].includes(needle)) {
      return i;
    }
  }
  return -1;
}

function printWindow(lines, center, context) {
  const start = Math.max(0, center - context);
  const end = Math.min(lines.length, center + context + 1);

  for (let i = start; i < end; i += 1) {
    const prefix = String(i + 1).padStart(6, " ");
    const line = lines[i].replace(/\r?\n$/, "");
    process.stdout.write(`${prefix}: ${line}\n`);
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (!fs.existsSync(args.log)) {
    process.stderr.write(`Log file not found: ${args.log}\n`);
    process.exit(1);
  }

  const lines = fs.readFileSync(args.log, "utf8").split(/\r?\n/);

  process.stdout.write("\n=== Token window ===\n");
  const tokenIndex = findFirstIndex(lines, args.token);
  if (tokenIndex === -1) {
    process.stdout.write(`Token not found: ${args.token}\n`);
  } else {
    printWindow(lines, tokenIndex, args.context);
  }

  process.stdout.write("\n=== Exception window ===\n");
  const exceptionThrownIndex = findFirstIndex(lines, "EXCEPTION_THROWN");
  const fatalErrorIndex = findFirstIndex(lines, "FATAL_ERROR");
  const systemIndex = findFirstIndex(lines, "System.");
  const exceptionIndex =
    exceptionThrownIndex !== -1
      ? exceptionThrownIndex
      : fatalErrorIndex !== -1
        ? fatalErrorIndex
        : systemIndex;

  if (exceptionIndex === -1) {
    process.stdout.write("No EXCEPTION_THROWN or FATAL_ERROR found\n");
  } else {
    printWindow(lines, exceptionIndex, args.context);
  }
}

main();
