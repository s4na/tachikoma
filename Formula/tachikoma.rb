# frozen_string_literal: true

# Homebrew formula for Tachikoma.
class Tachikoma < Formula
  desc "Minimal macOS menu bar app for Tachikoma"
  homepage "https://github.com/s4na/tachikoma"
  url "https://github.com/s4na/tachikoma/archive/refs/tags/v0.1.4.tar.gz"
  version "0.1.4"
  sha256 "af3a3b2da7a1166324c3fa686bcd6b1f2a412fbd569720c7615bda123a6937bf"
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
