#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION env var required}"
: "${SHA256:?SHA256 env var required}"
: "${HOMEBREW_TAP_GITHUB_TOKEN:?HOMEBREW_TAP_GITHUB_TOKEN env var required}"

TAP_DIR=$(mktemp -d)
trap 'rm -rf "$TAP_DIR"' EXIT

git clone --depth=1 \
  "https://x-access-token:${HOMEBREW_TAP_GITHUB_TOKEN}@github.com/nilBora/homebrew-apps.git" \
  "$TAP_DIR"

mkdir -p "$TAP_DIR/Casks"
cat > "$TAP_DIR/Casks/meeting-reminder.rb" <<EOF
cask "meeting-reminder" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/nilBora/meeting-reminder/releases/download/v#{version}/MeetingReminder-#{version}.dmg"
  name "Meeting Reminder"
  desc "Native macOS menu bar meeting reminder with full-screen overlay"
  homepage "https://github.com/nilBora/meeting-reminder"

  depends_on macos: ">= :ventura"

  app "MeetingReminder.app"

  caveats <<~EOS
    #{appdir}/MeetingReminder.app is not signed by Apple.
    If macOS blocks the app, re-install with:
      brew install --cask --no-quarantine meeting-reminder
    Or right-click the app in Finder → Open the first time.
  EOS

  zap trash: [
    "~/Library/Preferences/com.meetingreminder.app.plist",
    "~/Library/Caches/com.meetingreminder.app",
  ]
end
EOF

cd "$TAP_DIR"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add Casks/meeting-reminder.rb
git commit -m "meeting-reminder ${VERSION}"
git push origin HEAD
