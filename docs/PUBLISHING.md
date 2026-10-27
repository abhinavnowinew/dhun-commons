# Publishing Dhun Commons as an installable Basecamp app

Basecamp does not have a central app store. It reads one or more **catalogs**
from Settings → Repositories. A catalog is two small JSON files plus the
`.lgx` artifacts they point at:

| File | Purpose |
|---|---|
| `logos-repo.json` | the catalog's identity card: `name`, `displayName`, `indexUrl`, optional `trustedSigners` |
| `index.json` | the generated package listing: every package, every version, the download URL, `rootHash`, embedded manifest and optional icon |

The format is documented by Logos in
[`catalog-format.md`](https://github.com/logos-co/logos-modules-release-tool/blob/main/docs/catalog-format.md).
This repository follows it exactly: descriptor `schemaVersion` 1, index
`schemaVersion` 2, `rootHash` copied from `manifest.hashes.root`, and the
`signature` key omitted for unsigned builds.

> **Status from this checkout.** There is no git remote configured here and no
> public hosting credentials. Nothing has been pushed or published from this
> machine, and no public catalog URL exists yet. The steps below are the
> complete path for the repository owner; the generator and validator work
> locally and are exercised by CI.

## 1. Bump the version

Edit `metadata.json`:

```json
"version": "0.3.0"
```

Basecamp 0.2.3 installs a **portable** variant. Do not publish the `-dev`
artifact: a module built for `darwin-arm64-dev` cannot be installed by the
released app.

## 2. Build the portable LGX

```sh
NIX_CONFIG="experimental-features = nix-command flakes" nix build .#lgx-portable
```

The artifact is a single `.lgx` file under `result/`. Rename it for release:

```sh
cp result/logos-dhun_commons-module.lgx dist/dhun_commons-0.3.0.lgx
```

## 3. Create the GitHub release

Create a public repository for the project (for example
`OWNER/dhun-commons`) and a release tagged `dhun_commons-v0.3.0`. Attach
`dhun_commons-0.3.0.lgx` as the release asset.

The asset URL becomes:

```text
https://github.com/OWNER/dhun-commons/releases/download/dhun_commons-v0.3.0/dhun_commons-0.3.0.lgx
```

## 4. Generate the catalog

```sh
node scripts/make-catalog.mjs \
  --lgx dist/dhun_commons-0.3.0.lgx \
  --github OWNER/dhun-commons \
  --release-tag dhun_commons-v0.3.0 \
  --released-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --out catalog
```

This writes:

```text
catalog/logos-repo.json
catalog/index.json
catalog/icons/<sha256>.png
```

The generator defaults to the release asset URL and to raw GitHub URLs for the
descriptor and index. Override them for GitHub Pages or another host:

```sh
node scripts/make-catalog.mjs \
  --lgx dist/dhun_commons-0.3.0.lgx \
  --url https://cdn.example.org/dhun/dhun_commons-0.3.0.lgx \
  --index-url https://cdn.example.org/dhun/index.json \
  --out catalog
```

For a descriptor hosted somewhere other than raw GitHub, edit its `indexUrl`
after generation. `index.json` is regenerated; `logos-repo.json` is hand-owned.

Re-running the generator adds versions to an existing `catalog/index.json`
instead of replacing the file. Versions with the same version number or the
same `rootHash` are replaced, so a rebuild is idempotent.

## 5. Validate and commit

```sh
node scripts/make-catalog.mjs --check catalog
git add catalog/index.json catalog/logos-repo.json catalog/icons
git commit -m "Publish Dhun Commons 0.3.0 catalog"
git push origin main
```

The catalog validator checks the descriptor and index shape, that every
version has `url`, `rootHash`, `releasedAt` and a manifest, that
`rootHash === manifest.hashes.root`, that package names agree, that the icon
file exists with the recorded SHA-256, and that no unsigned entry carries a
null `signature` key.

CI runs the same check whenever `catalog/index.json` exists.

## 6. Add the catalog in Basecamp

1. Copy the published descriptor URL:

   ```text
   https://raw.githubusercontent.com/OWNER/dhun-commons/main/catalog/logos-repo.json
   ```

2. In Basecamp open **Settings → Repositories**.
3. Add that URL and enable the repository.
4. Refresh the catalog.
5. Search for **Dhun Commons** and install it.

Adding a repository is a user action. No catalog URL is added automatically by
this module.

## Signing

The generator produces an **unsigned** catalog entry by omitting `signature`,
which the format requires for unsigned packages. Basecamp's signature-policy
setting decides what happens next: `none`, `warn` or `require`. With `warn` the
app installs after a warning; with `require` an unsigned package is refused.

This repository does not create or store a signing key, so there is no DID to
list in `trustedSigners`. To sign:

1. generate an Ed25519 key with the Logos `lgx` tooling, keeping the private
   key outside this repository;
2. sign the built `.lgx`;
3. copy the resulting signature envelope into the version entry (the generator
   copies `manifest.sig` automatically when present);
4. add the signer DID to `trustedSigners` in `logos-repo.json`.

Never commit a private key.

## Hosting checklist

- [ ] `logos-repo.json` is reachable over HTTPS and parses as JSON.
- [ ] `indexUrl` is an absolute HTTPS URL to `index.json`.
- [ ] Every version `url` returns the exact `.lgx` bytes.
- [ ] `rootHash` equals the `.lgx` manifest's `hashes.root`.
- [ ] `sha256` and `size` are recorded for humans and mirrors.
- [ ] The icon path resolves relative to the index URL.
- [ ] The release is public, not a draft.
- [ ] `node scripts/make-catalog.mjs --check catalog` passes.

## What is still not public

The desktop app in this repository is a Basecamp module backed by local
rehearsal data. Publishing the catalog makes the module installable; it does
not publish live farm inventory, grant chain finality, or create production
signing credentials. See the repository README for the exact state of the
wallet, messaging and relay features.
