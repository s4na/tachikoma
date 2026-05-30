# frozen_string_literal: true

# Homebrew formula for Tachikoma.
class Tachikoma < Formula
  desc "Minimal macOS menu bar app for Tachikoma"
  homepage "https://github.com/s4na/tachikoma"
  version "0.1.4"
  head "https://github.com/s4na/tachikoma.git", branch: "main"

  depends_on macos: :ventura

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/tachikoma"
  end

  def caveats
    <<~EOS
      Run `tachikoma` once after installation to register it for login startup.
      You can disable future login startup from Tachikoma's menu bar settings.
    EOS
  end

  test do
    assert_match "syncs its login startup setting", shell_output("#{bin}/tachikoma --help")
  end
end
