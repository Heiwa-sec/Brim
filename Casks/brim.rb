cask "brim" do
  version "1.4"
  sha256 "2385b8ac62c92170619f895284f98daaa0ba7cbc395b892f0b8b2065e8d6d4fc"

  url "https://github.com/Heiwa-sec/Brim/releases/download/v#{version}/Brim.dmg"
  name "Brim"
  desc "Dynamic Island-style Now Playing, lyrics and file tray for the Mac notch"
  homepage "https://github.com/Heiwa-sec/Brim"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Brim.app"

  zap trash: [
    "~/Library/Caches/Brim",
    "~/Library/Preferences/dev.brim.Brim.plist",
  ]

  caveats <<~EOS
    Brim is not notarized (it is signed with a free Apple Development certificate),
    so macOS will refuse to open it the first time.

    Open Brim once, then go to System Settings > Privacy & Security, scroll down
    to the message about Brim and click "Open Anyway".

    Or, from Terminal, remove the quarantine flag:
      xattr -dr com.apple.quarantine /Applications/Brim.app
  EOS
end
