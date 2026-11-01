#!/usr/bin/env node
// Build a Logos module catalog (logos-repo.json + index.json) from a built LGX.
//
// The schema follows logos-modules-release-tool/docs/catalog-format.md:
// descriptor schemaVersion 1, index schemaVersion 2, signature omitted for
// unsigned packages, rootHash copied from manifest.hashes.root.
//
// Usage:
//   node scripts/make-catalog.mjs --lgx dist/dhun_commons-0.3.0.lgx \
//     --github owner/repo --release-tag dhun_commons-v0.3.0 --out dist/catalog
//
//   node scripts/make-catalog.mjs --check dist/catalog

import { createHash } from "node:crypto";
import { gunzipSync } from "node:zlib";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { basename, join, resolve } from "node:path";

const CATALOG_NAME = "dhun-commons";
const DISPLAY_NAME = "Dhun Commons";
const DESCRIPTION = "A three-party seasonal treasury and field kitchen for Dhun's landscape: LEZ testnet accounts, steward profiles, node-day rewards through a 2-of-3 treasury, a whole-wallet assistant routed through Xenia over Logos delivery, free-text kitchen planning with zero-waste steps, an Open-Meteo and Ventusky agronomy and conservation advisory for five field zones, and a deterministic eight-agent civic simulation where residents' agents consult, pair, hand off and peer-check water, roads, agri, safety, waste and care work behind human gates.";
const HOMEPAGE = "https://dhun.life";

function usage() {
    console.error(`usage: node scripts/make-catalog.mjs --lgx <file.lgx> --github <owner/repo> --release-tag <tag> [options]
       node scripts/make-catalog.mjs --check <catalog-dir>

options:
  --out <dir>           output directory (default: dist/catalog)
  --url <https://…>     artifact URL (default: GitHub release asset URL)
  --index-url <https://…>  published index.json URL (default: raw GitHub main)
  --repo-url <https://…>   published logos-repo.json URL (default: raw GitHub main)
  --name <name>         catalog name (default: ${CATALOG_NAME})
  --display-name <name> catalog display name (default: ${DISPLAY_NAME})
  --released-at <iso>   release timestamp (default: now, seconds precision)
  --generated-at <iso>  index build timestamp (default: now)
  --publisher-ref <ref> provenance tag (default: <package>-v<version>)`);
}

function parseArgs(argv) {
    const args = {};
    for (let i = 0; i < argv.length; i += 1) {
        const key = argv[i];
        if (!key.startsWith("--")) throw new Error(`unexpected argument: ${key}`);
        const name = key.slice(2);
        if (name === "check") {
            const value = argv[i + 1];
            if (!value || value.startsWith("--")) throw new Error("--check needs a directory");
            args.check = value;
            i += 1;
            continue;
        }
        const value = argv[i + 1];
        if (value === undefined || value.startsWith("--")) throw new Error(`--${name} needs a value`);
        args[name] = value;
        i += 1;
    }
    return args;
}

function sha256(buffer) {
    return createHash("sha256").update(buffer).digest("hex");
}

function tarEntry(buffer, wanted) {
    let offset = 0;
    while (offset + 512 <= buffer.length) {
        const name = buffer.toString("utf8", offset, offset + 100).replace(/\0.*$/s, "").trim();
        if (!name) break;
        const sizeText = buffer.toString("utf8", offset + 124, offset + 136).replace(/\0.*$/s, "").trim();
        const size = parseInt(sizeText, 8);
        if (Number.isNaN(size)) throw new Error(`bad tar header at byte ${offset}`);
        const prefix = buffer.toString("utf8", offset + 345, offset + 500).replace(/\0.*$/s, "").trim();
        const full = prefix ? `${prefix}/${name}` : name;
        const start = offset + 512;
        if (full === wanted || full === `./${wanted}`) {
            return buffer.subarray(start, start + size);
        }
        offset = start + Math.ceil(size / 512) * 512;
    }
    return null;
}

function readManifest(lgxPath) {
    const raw = readFileSync(lgxPath);
    const tar = gunzipSync(raw);
    const manifestBytes = tarEntry(tar, "manifest.json");
    if (!manifestBytes) throw new Error("the LGX has no manifest.json");
    const manifest = JSON.parse(manifestBytes.toString("utf8"));
    if (!manifest.name || !manifest.version || !manifest.hashes || !manifest.hashes.root) {
        throw new Error("the LGX manifest is missing name, version or hashes.root");
    }
    return { manifest, tar, raw };
}

function extractIcon(tar, manifest, outDir) {
    if (!manifest.icon) return null;
    const bytes = tarEntry(tar, manifest.icon);
    if (!bytes) return null;
    const hash = sha256(bytes);
    const iconsDir = join(outDir, "icons");
    mkdirSync(iconsDir, { recursive: true });
    const file = `${hash}.png`;
    writeFileSync(join(iconsDir, file), bytes);
    return { path: `icons/${file}`, sha256: hash, size: bytes.length };
}

function isoSeconds(value) {
    if (!value) {
        const now = new Date();
        now.setUTCMilliseconds(0);
        return now.toISOString().replace(/\.\d{3}Z$/, "Z");
    }
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) throw new Error(`bad --released-at: ${value}`);
    return parsed.toISOString().replace(/\.\d{3}Z$/, "Z");
}

function versionRank(entry) {
    const at = Date.parse(entry.releasedAt || "");
    return Number.isNaN(at) ? 0 : at;
}

function loadIndex(path) {
    if (!existsSync(path)) return { schemaVersion: 2, repositoryName: CATALOG_NAME, generatedAt: "", packages: [] };
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    if (parsed.schemaVersion !== 2 || !Array.isArray(parsed.packages)) {
        throw new Error(`${path} is not a schemaVersion 2 catalog index`);
    }
    return parsed;
}

function upsert(index, name, version) {
    let pkg = index.packages.find((item) => item.name === name);
    if (!pkg) {
        pkg = { name, versions: [] };
        index.packages.push(pkg);
    }
    pkg.versions = pkg.versions.filter((item) => {
        const sameVersion = item.manifest && item.manifest.version === version.manifest.version;
        const sameRoot = item.rootHash === version.rootHash;
        return !sameVersion && !sameRoot;
    });
    pkg.versions.push(version);
    pkg.versions.sort((a, b) => versionRank(b) - versionRank(a));
    index.packages.sort((a, b) => a.name.localeCompare(b.name));
    return index;
}

function build(args) {
    if (!args.lgx) throw new Error("--lgx is required");
    if (!args.github && !args.url) throw new Error("--github <owner/repo> or --url <https://…> is required");
    if (args.github && !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(args.github)) {
        throw new Error("--github must look like owner/repo");
    }

    const lgxPath = resolve(args.lgx);
    const outDir = resolve(args.out || "dist/catalog");
    mkdirSync(outDir, { recursive: true });

    const { manifest, tar, raw } = readManifest(lgxPath);
    const filename = basename(lgxPath);
    const url = args.url || `https://github.com/${args.github}/releases/download/${args["release-tag"] || `${manifest.name}-v${manifest.version}`}/${filename}`;
    if (!/^https:\/\//.test(url)) throw new Error("the artifact URL must be https");

    const entry = {
        releasedAt: isoSeconds(args["released-at"]),
        publisherRef: args["publisher-ref"] || `${manifest.name}-v${manifest.version}`,
        url,
        urls: [url],
        size: raw.length,
        sha256: sha256(raw),
        rootHash: manifest.hashes.root,
        manifest
    };
    if (manifest.sig) entry.signature = manifest.sig;
    const icon = extractIcon(tar, manifest, outDir);
    if (icon) entry.icon = icon;

    const indexPath = join(outDir, "index.json");
    const index = loadIndex(indexPath);
    index.repositoryName = args.name || index.repositoryName || CATALOG_NAME;
    index.generatedAt = isoSeconds(args["generated-at"]);
    upsert(index, manifest.name, entry);
    writeFileSync(indexPath, `${JSON.stringify(index, null, 2)}\n`);

    const indexUrl = args["index-url"] ||
        (args.github ? `https://raw.githubusercontent.com/${args.github}/main/catalog/index.json` : "");
    if (indexUrl) {
        const descriptor = {
            schemaVersion: 1,
            name: index.repositoryName,
            displayName: args["display-name"] || DISPLAY_NAME,
            description: DESCRIPTION,
            homepage: args.homepage || (args.github ? `https://github.com/${args.github}` : HOMEPAGE),
            indexUrl,
            trustedSigners: []
        };
        writeFileSync(join(outDir, "logos-repo.json"), `${JSON.stringify(descriptor, null, 2)}\n`);
    }

    console.log(`catalog: ${indexPath}`);
    console.log(`package: ${manifest.name} ${manifest.version}`);
    console.log(`rootHash: ${entry.rootHash}`);
    console.log(`sha256:   ${entry.sha256}`);
    console.log(`url:      ${entry.url}`);
    if (indexUrl) console.log(`descriptor indexUrl: ${indexUrl}`);
}

function check(dir) {
    const root = resolve(dir);
    const indexPath = join(root, "index.json");
    if (!existsSync(indexPath)) throw new Error(`missing ${indexPath}`);
    const index = JSON.parse(readFileSync(indexPath, "utf8"));
    if (index.schemaVersion !== 2) throw new Error("index.json must declare schemaVersion 2");
    if (!index.repositoryName) throw new Error("index.json has no repositoryName");
    if (!index.generatedAt || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(index.generatedAt)) {
        throw new Error("index.json generatedAt must be second-precision UTC with a Z suffix");
    }
    if (!Array.isArray(index.packages) || !index.packages.length) throw new Error("index.json lists no packages");
    for (const pkg of index.packages) {
        if (!pkg.name || !Array.isArray(pkg.versions) || !pkg.versions.length) {
            throw new Error(`bad package entry: ${JSON.stringify(pkg.name)}`);
        }
        for (const version of pkg.versions) {
            for (const field of ["url", "rootHash", "releasedAt", "manifest"]) {
                if (!version[field]) throw new Error(`${pkg.name} is missing ${field}`);
            }
            if (!/^https:\/\//.test(version.url)) throw new Error(`${pkg.name} url must be https`);
            if (!/^[0-9a-f]{64}$/.test(version.rootHash)) throw new Error(`${pkg.name} rootHash must be sha256 hex`);
            if (version.manifest.hashes.root !== version.rootHash) throw new Error(`${pkg.name} rootHash does not match manifest.hashes.root`);
            if (version.manifest.name !== pkg.name) throw new Error(`${pkg.name} manifest name mismatch`);
            if ("signature" in version && !version.signature) throw new Error(`${pkg.name} has a null signature; omit the key instead`);
            if (version.icon) {
                const iconPath = join(root, version.icon.path);
                if (!existsSync(iconPath)) throw new Error(`missing icon ${iconPath}`);
                const bytes = readFileSync(iconPath);
                if (sha256(bytes) !== version.icon.sha256) throw new Error(`icon hash mismatch for ${iconPath}`);
            }
        }
    }
    const descriptorPath = join(root, "logos-repo.json");
    if (existsSync(descriptorPath)) {
        const descriptor = JSON.parse(readFileSync(descriptorPath, "utf8"));
        if (descriptor.schemaVersion !== 1) throw new Error("logos-repo.json must declare schemaVersion 1");
        for (const field of ["name", "displayName", "indexUrl"]) {
            if (!descriptor[field]) throw new Error(`logos-repo.json is missing ${field}`);
        }
        if (descriptor.name !== index.repositoryName) throw new Error("descriptor name and index repositoryName differ");
        if (!/^https:\/\//.test(descriptor.indexUrl)) throw new Error("descriptor indexUrl must be https");
    }
    console.log(`catalog OK: ${index.packages.length} package(s), ${index.packages.reduce((n, p) => n + p.versions.length, 0)} version(s)`);
}

try {
    const args = parseArgs(process.argv.slice(2));
    if (args.check) check(args.check);
    else build(args);
} catch (error) {
    console.error(`error: ${error.message}`);
    usage();
    process.exit(1);
}
