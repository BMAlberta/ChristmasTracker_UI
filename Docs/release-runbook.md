# Christmas Tracker — iOS Ad Hoc Release Runbook

**Distribution model:** IPA + manifest.plist hosted at
`https://content.bmalberta.com/distribution/tracker/<build>/`, installed via
`itms-services://` link. No TestFlight, no App Store.

**Deadline:** Build 500 must be on-device before **2026-11-25**. The 4.4 ad hoc
provisioning profile expires that day and every 4.4 install stops launching.

---

## Prerequisites (one-time setup)

### 1. Apple credentials

You need three things in your **login keychain** before you can archive:

| What | How to get it |
|------|---------------|
| Apple Distribution certificate + private key | Download the certificate from the Apple Developer portal (Certificates, Identifiers & Profiles → Certificates). The private key must already exist in your keychain from when you requested the certificate. If the private key is missing, revoke and re-issue. |
| Ad hoc provisioning profile | Download from the Developer portal (Profiles). Open the downloaded file — Xcode registers it automatically under `~/Library/MobileDevice/Provisioning Profiles`. Every device you want to install on must be in the profile. |

Verify: `security find-identity -v -p codesigning | grep "Apple Distribution"` — you should see your certificate.

### 2. Register test devices

Each device must be registered in the Apple Developer portal before the
provisioning profile is re-downloaded:

1. Device → Settings → General → VPN & Device Management → find your app → note the UDID (or use `cfgutil` / Xcode).
2. Add the UDID in the Developer portal (Devices → All Devices → +).
3. Add the device to the ad hoc provisioning profile (Profiles → edit → Devices).
4. Download the updated profile and open it on your Mac.

### 3. Create `scripts/release.env`

```bash
cp scripts/release.env.example scripts/release.env
```

Fill in the real values (this file is gitignored and must never be committed):

```
RELEASE_TEAM_ID=<your 10-character Apple team ID>
RELEASE_PROFILE_NAME=<exact profile name as shown in Xcode organiser>
RELEASE_BUNDLE_ID=com.alberta.ChristmasTracker
RELEASE_S3_BUCKET=<the S3 bucket name>
RELEASE_S3_PREFIX=distribution/tracker
RELEASE_PUBLIC_BASE_URL=https://content.bmalberta.com
RELEASE_EXPORT_METHOD=release-testing
RELEASE_MIN_PROFILE_DAYS=14
# Uncomment if using a named AWS profile:
# RELEASE_AWS_PROFILE=your-aws-profile
```

Find your team ID: Apple Developer portal → Account → Membership Details.

Find your profile name: Xcode → Settings → Accounts → Manage Certificates, or
the downloaded `.mobileprovision` filename (it uses a UUID; use the Name from
`scripts/release.sh preflight --dry-run` or Xcode).

### 4. Configure AWS credentials

The script uses the AWS CLI to upload to S3. Configure an IAM user or profile that
has `s3:PutObject` on `s3://<bucket>/distribution/tracker/*` and `s3:ListBucket`:

```bash
aws configure --profile <profile-name>
# Enter access key, secret key, region (us-east-1 or wherever the bucket is)
```

Then set `RELEASE_AWS_PROFILE=<profile-name>` in `scripts/release.env`.

Verify: `aws s3 ls s3://<bucket>/distribution/tracker/ --profile <profile>` should
succeed (empty or existing listing is fine).

### 5. Install the itms-services link on a device

The install link works only over HTTPS. Send the link to yourself (AirDrop, iMessage,
Mail) and tap it on the device. Safari on iOS is required — Chrome does not support
`itms-services://`.

---

## Release procedure (step-by-step)

### Before you start

- Ensure the app builds cleanly: `scripts/build.sh`
- Ensure all tests pass: `scripts/verify.sh`
- Confirm you are on `master` and that your HEAD is pushed:
  ```
  git status          # must be clean
  git log --oneline -1
  git fetch origin master && git diff HEAD origin/master
  ```

### Choose a build number

The build number is `CURRENT_PROJECT_VERSION` passed to `xcodebuild` on the command
line. Rules:
- Must be an integer ≥ 500
- Must be strictly greater than the highest build in `scripts/.release-ledger`
- First release: use `500`
- Subsequent releases: use the previous build + 1 (or any larger integer)

### Step 1 — Preflight

```bash
bash scripts/release.sh preflight --build 500
```

Preflight checks:
- Required tools found (xcodebuild, plutil, codesign, security, aws, unzip, shasum, git)
- Git working tree is clean
- Current branch is `master`
- HEAD equals `origin/master` (or pass `--allow-unpushed` to skip)
- env values present and valid
- Ad hoc provisioning profile found, not expired within `RELEASE_MIN_PROFILE_DAYS` days,
  bundle ID matches, team ID matches, `get-task-allow` is false
- Apple Distribution signing identity found in keychain
- `scripts/verify.sh` passes

**Preflight must exit 0 before proceeding.**

If the profile expiry warning fires within 14 days, renew the profile before
releasing (Developer portal → Profiles → regenerate, download, open).

### Step 2 — Archive

```bash
bash scripts/release.sh archive --build 500
```

Runs `xcodebuild archive` with the `ChristmasTracker` scheme, `Release`
configuration, `generic/platform=iOS` destination, manual signing, and
`CURRENT_PROJECT_VERSION=500`. Produces:

```
build/release/500/ChristmasTracker.xcarchive
```

This takes 2–5 minutes on a cold build.

### Step 3 — Export

```bash
bash scripts/release.sh export --build 500
```

Writes `ExportOptions.plist` and runs `xcodebuild -exportArchive`. Produces:

```
build/release/500/ChristmasTracker-5.0-500.ipa
```

### Step 4 — Verify IPA

```bash
bash scripts/release.sh verify-ipa --build 500
```

Checks the IPA in place (without uploading). All of the following must pass:

- `CFBundleIdentifier` = `com.alberta.ChristmasTracker`
- `CFBundleVersion` = `500`
- `CFBundleShortVersionString` = `5.0`
- `API_BASE_URL` = `https://api.bmalberta.com`
- `API_MODE` = `real`
- `APP_ENVIRONMENT` = `production`
- No `NSAllowsArbitraryLoads` = true
- `NSFaceIDUsageDescription` present
- Embedded profile: ad hoc, not expired, `get-task-allow` = false
- `codesign --verify --strict` passes, team ID matches
- No debug entitlement in app binary
- `Config-Secrets.xcconfig` not in the bundle

**Do not upload if verify-ipa fails.**

### Step 5 — Generate manifest

```bash
bash scripts/release.sh manifest --build 500
```

Produces `build/release/500/manifest.plist`. Validates with `plutil -lint`.

### Step 6 — Upload

```bash
bash scripts/release.sh upload --build 500 --yes
```

- Checks that neither `ChristmasTracker-5.0-500.ipa` nor `manifest.plist` already
  exist on S3 (refuses to overwrite; build numbers can never be reused)
- Uploads the IPA, then the manifest
- Re-verifies both objects exist on S3 and prints their sizes
- Writes a ledger entry to `scripts/.release-ledger`

Omit `--yes` and add `--dry-run` to preview the commands without executing them.

### Step 7 — Confirm install info and run policy:set

```bash
bash scripts/release.sh install-info --build 500
```

Copy the `policy:set` block from the output and run it on the **API server** (not
here — the script never runs `policy:set`):

```
npm run policy:set -- --platform ios \
  --latest-build 500 --latest-version 5.0 \
  --manifest-url 'https://content.bmalberta.com/distribution/tracker/500/manifest.plist' \
  --ipa-url 'https://content.bmalberta.com/distribution/tracker/500/ChristmasTracker-5.0-500.ipa'
```

Decide whether to raise `--min-build`. Raising it forces devices on older builds to
update before they can use the app. For the first release (500 replacing 4.4), there
is no prior v2 build to force off, so you can leave `--min-build` at its default or
set it to 500 to block the 4.4 distribution channel entirely.

### Step 8 — Run all subcommands in one shot (alternative)

```bash
bash scripts/release.sh all --build 500 --yes
```

Runs: preflight → archive → export → verify-ipa → manifest → upload → install-info,
stopping on any failure. Use this only after you have confirmed preflight passes on
its own and you understand what each step does.

### Step 9 — Device verification

1. Send the `itms-services://` link to yourself (from `install-info` step 1).
2. Tap the link in Safari on a registered device.
3. Confirm the prompt says "Christmas Tracker" version 5.0.
4. Install. The app should replace 4.4 (same bundle ID, same slot).
5. After launch: Settings → General → VPN & Device Management → verify version 5.0 (500).
6. Log in. Confirm the app reaches production (`https://api.bmalberta.com`).
7. Check Sentry for a session event with `CFBundleVersion = 500`.

---

## 4.4 coexistence notes

- v2 (`com.alberta.ChristmasTracker`) shares the bundle ID with 4.4. Installing v2
  replaces 4.4 in place; there is no parallel install.
- The 4.4 ad hoc profile expires **2026-11-25**. After that date, every device running
  4.4 will show "unable to verify" or simply refuse to open it. You must have v2
  on-device before that date.
- The 4.4 codebase lives on the branch `legacy/4.4` and the tag `4.4`. Do not touch it.
- If a device refuses to install v2 (certificate or profile error), verify its UDID is
  in the ad hoc provisioning profile used for the v2 build.

---

## Rollback

**Never delete an uploaded build.** The itms-services link for any build that was
ever distributed will continue to work as long as the objects exist on S3.

To roll back to a previous build, point the version policy back at that build's URLs:

```bash
npm run policy:set -- --platform ios \
  --latest-build <prev-build> --latest-version <prev-version> \
  --manifest-url 'https://content.bmalberta.com/distribution/tracker/<prev-build>/manifest.plist' \
  --ipa-url 'https://content.bmalberta.com/distribution/tracker/<prev-build>/ChristmasTracker-<prev-version>-<prev-build>.ipa'
```

The first release (500) has nothing to roll back to. If 500 is broken and you need
the app working immediately, re-sign a corrected build as 501.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `Provisioning profile not found` | Profile not installed on this Mac | Download and open the `.mobileprovision` from the Developer portal |
| `Profile expires in N days (minimum M)` | Profile is about to expire | Renew the profile in the Developer portal, download, and open |
| `get-task-allow is true in profile` | Using a Development profile instead of Ad Hoc | Download and use the correct Ad Hoc distribution profile |
| `Apple Distribution identity not found` | Certificate not in keychain | Import the certificate (`.cer`) from the Developer portal; ensure the matching private key is in the keychain |
| `Working tree is not clean` | Uncommitted or unstaged files | `git status` and stash or commit pending changes |
| `HEAD does not match origin/master` | Local commit not pushed | Push first, or use `--allow-unpushed` (never for a production release) |
| `Object already exists on S3` | Build number was previously uploaded | Increment the build number; never reuse a build number |
| `codesign --verify --strict failed` | Archive produced an invalid signature | Rebuild; ensure the correct Distribution certificate is active and the profile is re-downloaded |
| Safari shows "Cannot connect to ...installer" | Public URL not reachable | Confirm the manifest and IPA are accessible: `curl -I 'https://content.bmalberta.com/distribution/tracker/500/manifest.plist'` |
| Device not in provisioning profile | UDID not registered | Add the device UDID to the Developer portal, regenerate the profile, re-release |
