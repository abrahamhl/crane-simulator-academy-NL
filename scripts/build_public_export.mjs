/**
 * Builds the public export tree under build/public/.
 *
 * ALLOW-LIST, NOT DENY-LIST. A deny-list leaks the first time someone adds a
 * file to a directory nobody thought to exclude; this script copies only what
 * is explicitly named, and refuses to run if anything on the list is missing.
 * Everything commercial therefore stays private by DEFAULT rather than by
 * remembering to exclude it.
 *
 * The working repository keeps its full history, including research material
 * and the commercial design. The public repository is created fresh from this
 * tree with NO shared history, so nothing that was ever committed privately
 * can be recovered from it.
 *
 *   node scripts/build_public_export.mjs [outDir]
 */
import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync, writeFileSync, readFileSync } from "node:fs";
import { join, dirname, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = process.argv[2] ? join(ROOT, process.argv[2]) : join(ROOT, "build", "public");

/** Directories copied wholesale. */
const DIRS = [
  "src/simulator/core",
  "src/simulator/environments",
  "src/simulator/game",
  "src/simulator/machines",
  "src/simulator/scenarios",
  "src/simulator/tests",
  "src/simulator/ui",
  "docs/public",
  ".claude/agents",
  ".claude/skills",
  ".claude/rules",
];

/** Individual files copied. */
const FILES = [
  "src/simulator/project.godot",
  "src/simulator/export_presets.cfg",
  "src/simulator/icon.svg",
  "src/simulator/icon.svg.import",
  "README.md",
  "LICENSE",
  "CHANGELOG.md",
  "DECISIONS.md",
  "PROJECT_STATE.md",
  "AGENTS.md",
  "CLAUDE.md",
  "START_SIMULATOR.bat",
  "RUN_TESTS.bat",
  ".gitignore",
  "logs/MODULE_TEST_RESULTS.json",
  "logs/SELFTEST_RESULTS.json",
  "logs/TEST_LOG.md",
  // Named individually rather than copying scripts/ wholesale: the older
  // Python validators there target a schema this release replaced, and
  // shipping stale tooling is worse than shipping none.
  "scripts/build_public_export.mjs",
];

/**
 * Paths that must NEVER appear in the export, checked after the copy as a
 * belt-and-braces audit. If the allow-list is ever widened carelessly, this
 * fails the build rather than shipping the leak.
 */
const FORBIDDEN_PATTERNS = [
  /(^|[\\/])COMMERCIAL([\\/]|$)/i,
  /(^|[\\/])research([\\/]|$)/i,
  /(^|[\\/])memory([\\/]|$)/i,
  /01_MASTER_PROMPT/i,
  /02_KICKOFF/i,
  /REPORTE_FINAL/i,
  /SESSION_HANDOFF/i,
  /\.env$/i,
  /\.docx$/i,
  /\.zip$/i,
  /(^|[\\/])tools([\\/]|$)/i,   // the bundled engine binary is not ours to redistribute
  /settings\.local\.json$/i,
  // The bash-logging hook writes COMMAND_LOG.md into whatever directory it is
  // invoked from, which has already landed one inside docs/public. It records
  // full local paths and belongs in no published tree.
  /COMMAND_LOG/i,
  /bash_commands/i,
];

function walk(dir, base = dir, out = []) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) walk(p, base, out);
    else out.push(relative(base, p));
  }
  return out;
}

// --- build ----------------------------------------------------------------
const missing = [...DIRS, ...FILES].filter((p) => !existsSync(join(ROOT, p)));
if (missing.length) {
  console.error("Refusing to build: allow-listed paths are missing:");
  for (const m of missing) console.error("  -", m);
  process.exit(1);
}

if (existsSync(OUT)) rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

for (const d of DIRS) {
  cpSync(join(ROOT, d), join(OUT, d), {
    recursive: true,
    // Godot's import cache and uid files are machine-local noise.
    filter: (src) => !/[\\/]\.godot[\\/]/.test(src) && !src.endsWith(".uid"),
  });
}
for (const f of FILES) {
  mkdirSync(dirname(join(OUT, f)), { recursive: true });
  cpSync(join(ROOT, f), join(OUT, f));
}

// The public tree needs its own ignore rules: no build output, no engine.
writeFileSync(join(OUT, ".gitignore"), [
  "# Godot import cache and machine-local ids",
  ".godot/",
  "*.uid",
  "",
  "# The engine binary is downloaded, not vendored",
  "tools/",
  "",
  "# Local player profile and build output",
  "build/",
  "release/",
  "*.zip",
  "",
  "# Commercial material never belongs in the public repository",
  "COMMERCIAL/",
  "research/",
  "memory/",
  "",
  "# OS noise",
  "Thumbs.db",
  "Desktop.ini",
  "",
].join("\n"), "utf8");

// --- audit ----------------------------------------------------------------
const shipped = walk(OUT);
const leaks = shipped.filter((p) => FORBIDDEN_PATTERNS.some((re) => re.test(p)));
if (leaks.length) {
  console.error("LEAK CHECK FAILED — these files must not be published:");
  for (const l of leaks) console.error("  -", l);
  process.exit(1);
}

// Scan text files for markers the commercial docs are required to carry, so a
// stray paste of pricing or partner material is caught before it is pushed.
// Assembled from fragments on purpose: written as literals, this file would
// match its own scan and fail the build it is meant to protect.
const MARKERS = [
  new RegExp(["GOA", "CONFIDENTIAL"].join("-")),
  new RegExp(["COMMERCIAL", "ONLY"].join("-")),
];
const textLeaks = [];
for (const rel of shipped) {
  if (!/\.(md|gd|json|txt|bat|tscn|godot|mjs|js)$/i.test(rel)) continue;
  const body = readFileSync(join(OUT, rel), "utf8");
  if (MARKERS.some((re) => re.test(body))) textLeaks.push(rel);
}
if (textLeaks.length) {
  console.error("LEAK CHECK FAILED — confidential markers found in:");
  for (const l of textLeaks) console.error("  -", l);
  process.exit(1);
}

const bytes = shipped.reduce((n, p) => n + statSync(join(OUT, p)).size, 0);
console.log(`public export ready: ${OUT}`);
console.log(`  ${shipped.length} files, ${(bytes / 1024 / 1024).toFixed(2)} MB`);
console.log(`  leak check: clean (${FORBIDDEN_PATTERNS.length} patterns, ${MARKERS.length} markers)`);
console.log("");
console.log("This tree is standalone. Publish it with NO shared history:");
console.log(`  cd ${OUT.split(sep).join("/")} && git init -b main && git add -A && git commit`);
