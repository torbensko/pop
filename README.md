# Pop

A native macOS 14+ menu-bar launcher for applications and selected folders, with a small calculator.

Open `Pop.xcodeproj` in Xcode and run the Pop scheme. Xcode resolves KeyboardShortcuts and Sparkle as package dependencies.

- **Control–Option–Space** toggles the launcher. Change the shortcut in **Pop → Settings…**.
- Type an app or folder name. Abbreviations like `vis co` and `vsco` match Visual Studio Code. Missing letters, extra letters, substitutions, and adjacent swapped letters are tolerated (for example, `blendre` matches Blender). Matching ignores case and accents; intentional abbreviations preserve letter order. Queries of one or two letters require a literal subsequence to avoid noisy matches.
- Exact and prefix matches rank above abbreviations, which rank above typo matches. Applications receive a boost; frequently opened items also receive a capped boost, so a frequently used folder can outrank a similarly matching app without burying exact matches.
- With an empty search, Pop shows horizontal rows of up to three folder cards and five application cards. Left/Right moves between cards; Up/Down moves between the folder and application rows. Typing switches to a vertical search results list. Successful opens through Pop increase an item's frequency, saved across restarts; recent use breaks frequency ties on the start view. Before it has history, suggestions use Documents and Downloads followed by alphabetical choices. It does not track opens from Finder or other apps, and it indexes apps and folders rather than individual files.
- Use arrow keys and Return to open a result, or click it. Escape closes the panel.
- In Settings, choose one or more folder locations and a separate depth for each. Depth **0** includes the root only; **1** includes immediate subfolders; **2** includes grandchildren. The maximum is 20.
- Documents and Downloads are included automatically at depth 0. Standard application locations are indexed automatically, including Utilities. Hidden directories, symlinks, and bundle contents are excluded. Overlapping folder roots are deduplicated.
- Type **= (24 + 6) / 3** for calculator mode. Supports decimals, unary signs, `+`, `-`, `*`, `/`, `^`, and parentheses. Return copies the result. Invalid expressions and non-finite results are not copied. Expressions are limited to 256 characters; results use floating-point arithmetic and display up to 14 significant digits.

The index refreshes at launch, after folder changes, and through **Reindex**. Filesystem changes are not watched. Scanning runs in the background. Unreadable folders are reported in the UI.

Settings are stored at `~/Library/Application Support/Pop/config.json`:

```json
{
  "folders": [
    { "path": "~/Projects", "depth": 2 }
  ]
}
```

A missing config is created with no folder roots. Malformed configuration fails with an error naming the file. Reindex reloads hand-edited configuration. Launch counts and last-open dates are stored locally in `~/Library/Application Support/Pop/usage.json`. The global shortcut is stored separately in user defaults by KeyboardShortcuts.

## Validation

From this directory:

```sh
xcodebuild -project Pop.xcodeproj -scheme Pop -derivedDataPath /tmp/pop-build CODE_SIGNING_ALLOWED=NO build
swiftc Pop/Index.swift Pop/UsageStore.swift Pop/Calculator.swift Tests/main.swift -o /tmp/pop-core-tests
/tmp/pop-core-tests
```

Manual checks: toggle from another app and type immediately; navigate with arrows; launch an app and open a folder; Escape and reopen; toggle over a full-screen app; change folder depth and verify results; calculate and paste the copied answer.

## Version and artwork

Settings and the menu-bar menu show the running bundle's version and build number. `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project are the source of truth. Increment the build number for a new distributed build and the version for a release. The current version is 1.1.0 (build 5).

The app icon comes from the user-designed `Artwork/pop-master.jpg`, preserved unchanged. The asset catalogue contains PNG exports at macOS icon sizes; the website uses the same master artwork.

## Public releases

`Scripts/check.sh` checks the core behavior and builds the app. `Scripts/package.sh --unsigned` creates a local preview DMG and ZIP, clearly named as unsigned. The distribution build contains Apple Silicon and Intel binaries and targets macOS 14 or later; Intel and older macOS versions have not been tested interactively.

The manual **Build and release** GitHub workflow signs, notarises, staples, and publishes a DMG, ZIP, and checksums. Before running it, configure the five repository Actions secrets used by Brief: `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_ID_PASSWORD`, and `APPLE_TEAM_ID`. Also configure `SPARKLE_PRIVATE_KEY` for signing update archives. The certificate must be a Developer ID Application certificate. GitHub does not allow reading existing secret values back from another repository.

Local distribution packaging accepts those Apple credentials plus `SIGNING_IDENTITY` through environment variables. Keep credentials out of source and shell history. The release workflow refuses to replace an existing version.

### First release setup

1. Add the six secrets above under **Settings → Secrets and variables → Actions → Secrets** in the Pop repository. Use the original signing certificate and credentials from Brief; its repository secrets do not carry over automatically. `CERTIFICATE_P12` is the base64-encoded exported certificate, and `CERTIFICATE_PASSWORD` unlocks that export. `APPLE_ID_PASSWORD` is an Apple app-specific password.
2. No Actions variables are required. The default runner is `xcode-27`, matching Brief's successful release. Set the optional `MACOS_RUNNER` variable only if you need to change the runner.
3. Open **Actions → Build and release → Run workflow**, select `main`, and run it. Publishing is manual, not triggered by a push.
4. After the run succeeds, the public release provides `Pop.dmg`, `Pop.zip`, and `SHA256SUMS.txt`. The stable download URL is `https://github.com/torbensko/pop/releases/latest/download/Pop.dmg`. Add this as the website entry's `downloadUrl` once the first release exists.

For subsequent releases, increment the version and build number in the Xcode project and update `RELEASE_NOTES.md` before running the workflow.

## Everyday use and development builds

Use `/Applications/Pop.app` as the everyday copy. Install the exact signed, notarised app from a GitHub release—the same artifact offered by the website. Do not overwrite it with a raw Xcode build or an unsigned preview merely because a local build passed.

For a fix ready for everyday use:

1. Run the checks, increment the version and build number, and update the release notes.
2. Publish through **Build and release** and wait for signing and notarisation to succeed.
3. Download that release, check its checksums and signature, and quit the running Pop before replacing the app bundle in Applications. Replace the whole bundle rather than merging new files into an old bundle. Keep the previous release available for rollback.
4. Launch only the Applications copy and verify its version. The website's latest-release download link follows the new release automatically.

Keep the bundle identifier (`sko.Pop`) and Developer ID signing identity consistent across releases. macOS uses the app's code-signing requirements to recognise it for privacy permissions; placing an unsigned or differently signed build at the same path does not make it the same identity. A development-to-release transition may require permission again. Consistent release signing supports permission continuity, but does not guarantee that macOS will never prompt.

Development builds remain separate from the everyday copy and should only be launched deliberately for testing. Stop them afterwards to avoid duplicate menu icons or shortcut conflicts. Updates must preserve the user's config, launch history, shortcut preferences, and privacy settings. Never reset permissions as part of an update.

## In-app updates

Release copies installed in `/Applications/Pop.app` or `~/Applications/Pop.app` use Sparkle to check on launch and periodically, and download updates automatically by default. Users can change these preferences in Settings or choose **Check for Updates…** from the menu. Sparkle handles verification, installation and relaunch; downloading an update does not mean it has already been installed. Debug builds and Release builds outside those installation locations do not start the updater.

The release workflow signs the final ZIP with the dedicated Sparkle key and publishes `appcast.xml` alongside the release assets. The feed references a version-specific ZIP, so a newer release cannot change the bytes behind an older signature. Keep incrementing the build number: Sparkle uses it to order updates. The public key lives in `Config/Info.plist`; the private key is in the local Keychain under the `pop-updates` account and in GitHub's `SPARKLE_PRIVATE_KEY` secret. Never commit or log the private key. Preserve this key across releases.

Version 1.1.0 is the first release with an updater. Older versions need one manual installation of 1.1.0 or later. Subsequent signed releases use the in-app update path. The user can ask the agent to reopen the development build after restarting their Mac; they do not need to navigate build folders. Quit the other copy first to avoid shortcut conflicts. Development signing may have separate privacy permissions from release signing.
