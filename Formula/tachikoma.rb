# frozen_string_literal: true

# Homebrew formula for Tachikoma.
class Tachikoma < Formula
  desc "Minimal macOS menu bar app for Tachikoma"
  homepage "https://github.com/s4na/tachikoma"
  version "0.1.2"
  head "https://github.com/s4na/tachikoma.git", branch: "main"

  depends_on macos: :ventura

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/tachikoma"
  end

  def post_install
    launch_agents = Pathname("#{Dir.home}/Library/LaunchAgents")
    launch_agents.mkpath
    legacy_plist = launch_agents/"homebrew.mxcl.tachikoma.plist"
    legacy_plist.unlink if legacy_plist.exist?

    startup_off = `/usr/bin/defaults read com.s4na.tachikoma startupOff 2>/dev/null`.strip == "1"
    return if startup_off

    plist = launch_agents/"com.s4na.tachikoma.plist"
    plist.write <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.s4na.tachikoma</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/tachikoma</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
      </dict>
      </plist>
    XML

    ohai "Tachikoma will open automatically from the next login."
  end

  test do
    assert_match "syncs its login startup setting", shell_output("#{bin}/tachikoma --help")
  end
end
