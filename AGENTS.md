# Pop development and installation

The user uses Pop as an ordinary customer would. Their everyday copy is `/Applications/Pop.app`, installed from the exact signed and notarised GitHub release offered on the website.

- Do not automatically install or launch raw development builds over the everyday copy. Test builds separately and stop test instances afterwards.
- When delivering a fix for everyday use, follow README's release/install procedure. Verify the release before installation, quit Pop before replacement, replace the whole bundle, and verify the running version afterwards.
- Preserve `sko.Pop` and the existing Developer ID signing identity across releases. Preserve user settings, launch history, shortcuts, and privacy permissions; do not reset them.
- Bump the version and build number for a new release. Local test builds do not require publication.
- Report automated checks separately from interactive UI testing; do not claim keyboard/UI validation when automation was unavailable.

The user is happy to ask the agent to reopen the development build after restarting their Mac. Find the latest deliberate test build, confirm its version, and stop the everyday copy before launching it. Do not make the user manage build directories. Keep tested changes moving through the signed release process; the Applications copy updates through Sparkle after its one-time bootstrap installation. Do not claim an update has installed merely because the release or download succeeded.
