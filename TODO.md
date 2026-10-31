# TODO

Status after the `macos-app-scaffold` audit. Tick as you go; delete what you decide not to do.

## Done
- [x] LICENSE (MIT)
- [x] AGENTS.md + CLAUDE.md symlink
- [x] `VERSION` file as the single source of truth (read by `scripts/make-app.sh`)
- [x] SwiftLint config (`.swiftlint.yml`)
- [x] GitHub Actions: build + test, universal release build, optional sign + notarize, DMG, GitHub release
- [x] README exists, `.gitignore` covers `.build/`, `build/`

## Release
- [ ] Set the five signing secrets and cut a `v*` tag — verify the artifact with
      `spctl -a -vv`, `xcrun stapler validate`, `lipo -archs arm64 x86_64`
- [ ] Change the LICENSE copyright holder if it should be a person/company, not "contributors"
- [ ] Auto-update: Sparkle 2.x (needs `SUFeedURL` + `SUPublicEDKey` in the generated
      Info.plists, `Sparkle` SPM dep, CI appcast step) **or** lightweight GitHub
      release polling. Needs release infra first.
- [ ] Homebrew Cask (needs a tap repo or a PR to homebrew/cask; `:github_latest` livecheck)

## Product
- [ ] Settings/Preferences window — there is none today. Use the `macos-settings-ui`
      skill; add `CommandGroup(replacing: .appSettings)` and do **not** add a `Settings` scene
      (it opens behind other windows for an `LSUIElement` app).
- [ ] Launch at Login (`SMAppService.mainApp`, macOS 13+) — expected for a menu-bar recorder
- [ ] Welcome/onboarding window — frame the one-time ~550 MB model download before it starts
- [ ] Mic permission pre-flight — today a denial only surfaces as a failed card after Listen.
      Check `AVCaptureDevice.authorizationStatus(for: .audio)` and offer a Settings deep link.
- [ ] File-based logging (support bundle) — unified `os.Logger` only; users can't attach logs
- [ ] Localization — strings are English literals; pick system-following or the in-app
      `LocalizationOverride` mode from the scaffold skill, not both.

## Dev loop
- [ ] Run `swiftlint` locally (or add it to the CI workflow) and fix what it flags
- [ ] Xcode project for debugging? Not required — `swift build` + `scripts/make-app.sh` work.
      If added, generate with XcodeGen; never hand-edit `.pbxproj` alongside the scripts.

## Deliberately skipped
- [ ] Analytics (Aptabase) — conflicts with the "everything on this Mac" pitch
- [ ] App Sandbox / App Store — process audio taps and the direct-download flow are the
      current path; revisit only if the App Store becomes a goal
- [ ] Accessibility / Screen Recording permission gates — app uses neither API
- [ ] Background helper (SMAppService agent/daemon) — no separate process needed
