# frozen_string_literal: true

# Homebrew formula for Tachikoma.
class Tachikoma < Formula
  desc "Minimal macOS menu bar app for Tachikoma"
  homepage "https://github.com/s4na/tachikoma"
  url "https://github.com/s4na/tachikoma/archive/refs/tags/v0.1.5.tar.gz"
  version "0.1.5"
  sha256 "ceb9254967b02092befd95c7d0d669cc6834933a948806d2c9f57a82236809a3"
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
