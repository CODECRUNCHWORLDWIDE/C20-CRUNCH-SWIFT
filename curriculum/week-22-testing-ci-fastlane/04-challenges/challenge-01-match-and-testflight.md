# Challenge 1 — `match` + TestFlight from `main` (commit to build, untouched)

**Time.** 90–150 minutes (an Apple Developer membership is required).
**Deliverable.** A working `push`-to-`main` pipeline that ships to TestFlight, plus a short report (`SHIP-PIPELINE.md`) documenting the signing setup and a screenshot of the build appearing in App Store Connect's TestFlight tab, committed to your Week 22 repo (secrets redacted).

## The premise

The exercise-3 gate protects `main`. This challenge *ships* from it. The skill here is the one genuinely hard part of iOS CI: **code signing on a machine that isn't yours.** A fresh runner has no certificates, no profiles, no keychain, and Apple's signing model assumes a developer's personal Mac. fastlane's `match` solves it by storing one signing identity, encrypted, in a repo every machine fetches. Get this right once and shipping is silent; get it wrong and you lose a day to "No profiles were found."

You will set up `match`, wire an App Store Connect API key, and add a ship lane that runs only on a green `main`.

## What to build

You need: the Apple Developer membership (Phase III), an app record in App Store Connect (create one for your bundle id), and a **separate private Git repo** for the certificates (e.g. `yourorg/certificates`).

### Step 1 — Mint an App Store Connect API key

App Store Connect ▸ **Users and Access ▸ Integrations ▸ App Store Connect API** ▸ create a key (App Manager role is enough). Download the `.p8`, note the **Key ID** and **Issuer ID**. This authenticates `match`, `gym`, and `pilot` non-interactively — no Apple ID, no 2FA prompt a script can't answer. Same artifact shape as the Week 18 APNs key.

### Step 2 — Set up `match` once, from your laptop

Pin fastlane with Bundler so CI and your laptop run the same version:

```ruby
# Gemfile
source "https://rubygems.org"
gem "fastlane"
```

```ruby
# fastlane/Matchfile
git_url("git@github.com:yourorg/certificates.git")   # the PRIVATE certs repo
storage_mode("git")
type("appstore")
app_identifier("com.crunch.hellonotes")
```

```bash
bundle install
bundle exec fastlane match appstore     # creates + encrypts + commits the cert & profile
```

`match` prompts for a passphrase — this is your `MATCH_PASSWORD`. It creates a distribution certificate and an App Store provisioning profile, encrypts them with that passphrase, and commits them to the certs repo. Verify the certs repo now contains encrypted `.cer`/`.mobileprovision` files.

### Step 3 — The ship lane

```ruby
# fastlane/Fastfile
default_platform(:ios)

def asc_api_key
  app_store_connect_api_key(
    key_id: ENV["ASC_KEY_ID"],
    issuer_id: ENV["ASC_ISSUER_ID"],
    key_content: ENV["ASC_KEY_P8"],
    is_key_content_base64: true
  )
end

platform :ios do
  lane :ship_beta do
    api_key = asc_api_key
    setup_ci                                   # temporary keychain on the runner
    match(type: "appstore", readonly: true, api_key: api_key)   # CI fetches, never creates
    increment_build_number(build_number: ENV["GITHUB_RUN_NUMBER"])  # unique per run
    gym(
      scheme: "HelloNotes",
      export_method: "app-store",
      output_directory: "build",
      clean: true
    )
    pilot(
      api_key: api_key,
      skip_waiting_for_build_processing: true,
      distribute_external: false               # internal testers; no App Review needed
    )
  end
end
```

The CI-signing contract, made concrete:

- **`setup_ci`** creates a fresh temporary keychain so you're not fighting the runner's default.
- **`readonly: true`** — CI *fetches* the existing identity; it must never create/rotate certs (that would race runs). Creation happened once, on your laptop.
- **`increment_build_number` from `GITHUB_RUN_NUMBER`** — every build has a unique number, so TestFlight never rejects a duplicate.
- **API key everywhere** — `match`, and `pilot` authenticate with the `.p8`, not an Apple ID.

### Step 4 — Store the secrets

```bash
gh secret set MATCH_PASSWORD            # the match passphrase
gh secret set MATCH_GIT_TOKEN           # a PAT/deploy key with read access to the certs repo
gh secret set ASC_KEY_ID
gh secret set ASC_ISSUER_ID
gh secret set ASC_KEY_P8 < <(base64 -i AuthKey_XXXX.p8)   # base64 of the .p8
```

Never commit any of these. The `.p8`, the passphrase, and the certs-repo access are credentials to your developer account.

### Step 5 — The ship job (on `main`, after tests)

Add to `.github/workflows/ci.yml`:

```yaml
  ship:
    needs: test                              # only ship if the gate passed
    if: github.ref == 'refs/heads/main'      # only on main, never on a PR
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: '16.2' }
      - name: Install fastlane
        run: bundle install
      - name: Ship to TestFlight
        env:
          MATCH_PASSWORD:  ${{ secrets.MATCH_PASSWORD }}
          MATCH_GIT_BASIC_AUTHORIZATION: ${{ secrets.MATCH_GIT_TOKEN }}
          ASC_KEY_ID:      ${{ secrets.ASC_KEY_ID }}
          ASC_ISSUER_ID:   ${{ secrets.ASC_ISSUER_ID }}
          ASC_KEY_P8:      ${{ secrets.ASC_KEY_P8 }}
        run: bundle exec fastlane ship_beta
```

### Step 6 — Prove it: commit to `main`, build in TestFlight

This is the graded part:

1. Merge a trivial change to `main` (or push directly if it's your repo).
2. Watch the `ship` job: `gh run watch`. It should `setup_ci`, `match` (fetch the identity), `gym` (build the signed `.ipa`), and `pilot` (upload).
3. Open App Store Connect ▸ your app ▸ **TestFlight**. Within a few minutes, the new build (with your `GITHUB_RUN_NUMBER` build number) appears, ready for internal testers — **and you never opened Xcode.**

## Acceptance criteria

- [ ] `match` stores an encrypted `appstore` cert + profile in a separate private repo; the local `match appstore` succeeded.
- [ ] An App Store Connect **API key** authenticates `match`/`pilot` (no Apple ID); the `.p8`, key id, and issuer id are GitHub secrets.
- [ ] A `ship_beta` fastlane lane uses `setup_ci`, `match(readonly: true)`, `gym`, and `pilot`, with a unique build number per run.
- [ ] A GitHub Actions `ship` job runs **only on `main`, only after `test` passes**, and uploads to TestFlight.
- [ ] A build appears in App Store Connect's TestFlight tab from a `main` push, with no manual Xcode step.
- [ ] `SHIP-PIPELINE.md` documents the signing setup and includes the TestFlight screenshot (secrets redacted).
- [ ] No credential is committed to the repo.

## What "great" looks like

A weak submission says "it uploaded to TestFlight." A great submission says:

> A push to `main` triggers the `ship` job after the `test` gate is green. `setup_ci` makes a temporary keychain; `match(type: "appstore", readonly: true)` fetches the distribution cert and App Store profile from the private `certificates` repo and decrypts them with `MATCH_PASSWORD`; `gym` archives and exports a signed `.ipa` with `export_method: app-store`; `pilot` uploads it via the App Store Connect API key. Build `#${GITHUB_RUN_NUMBER}` appeared in TestFlight ~4 minutes later. The one trap: my first run failed with "No profiles were found" because I'd set `readonly: true` before ever running `match` to *create* the profile — `readonly` only fetches, so the create has to happen once on a laptop first. The second trap: `pilot` initially asked for an Apple ID password until I passed the `api_key:` explicitly to it as well as to `match`.

Backend-of-the-pipeline, untouched-by-human, and honest about the two signing traps. That's the senior answer.

## Where this reappears

This pipeline is the capstone's operational backbone — "ship to TestFlight in five regions" is `pilot` plus App Store Connect region settings on top of exactly this lane. And the CI-signing model (`match` storing one identity every machine fetches, API-key auth, secrets in the runner) is how every professional iOS team ships. The day-saving knowledge here — that signing is *the* hard part and `match` is the answer — is worth more than any single test you'll write.
