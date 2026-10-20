# Pop

A native macOS 14+ menu-bar launcher for applications and selected folders, with a small calculator.

Open `Pop.xcodeproj` in Xcode and run the Pop scheme. The only package dependency is KeyboardShortcuts, resolved by Xcode.

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

Settings and the menu-bar menu show the running bundle's version and build number. `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project are the source of truth. Increment the build number for a new distributed build and the version for a release. The current version is 1.0.1 (build 4).

The app icon comes from the user-designed `Artwork/pop-master.jpg`, preserved unchanged. The asset catalogue contains PNG exports at macOS icon sizes; the website uses the same master artwork.

## Public releases

`Scripts/check.sh` checks the core behavior and builds the app. `Scripts/package.sh --unsigned` creates a local preview DMG and ZIP, clearly named as unsigned. The distribution build contains Apple Silicon and Intel binaries and targets macOS 14 or later; Intel and older macOS versions have not been tested interactively.

The manual **Build and release** GitHub workflow signs, notarises, staples, and publishes a DMG, ZIP, and checksums. Before running it, configure the same five repository Actions secrets used by Brief: `CERTIFICATE_P12`, `CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_ID_PASSWORD`, and `APPLE_TEAM_ID`. The certificate must be a Developer ID Application certificate. GitHub does not allow reading existing secret values back from another repository.

Local distribution packaging accepts those Apple credentials plus `SIGNING_IDENTITY` through environment variables. Keep credentials out of source and shell history. The release workflow refuses to replace an existing version.

### First release setup

1. Add the five secrets above under **Settings → Secrets and variables → Actions → Secrets** in the Pop repository. Use the original signing certificate and credentials from Brief; its repository secrets do not carry over automatically. `CERTIFICATE_P12` is the base64-encoded exported certificate, and `CERTIFICATE_PASSWORD` unlocks that export. `APPLE_ID_PASSWORD` is an Apple app-specific password.
2. No Actions variables are required. The default runner is `xcode-27`, matching Brief's successful release. Set the optional `MACOS_RUNNER` variable only if you need to change the runner.
3. Open **Actions → Build and release → Run workflow**, select `main`, and run it. Publishing is manual, not triggered by a push.
4. After the run succeeds, the public release provides `Pop.dmg`, `Pop.zip`, and `SHA256SUMS.txt`. The stable download URL is `https://github.com/torbensko/pop/releases/latest/download/Pop.dmg`. Add this as the website entry's `downloadUrl` once the first release exists.

For subsequent releases, increment the version and build number in the Xcode project and update `RELEASE_NOTES.md` before running the workflow.
