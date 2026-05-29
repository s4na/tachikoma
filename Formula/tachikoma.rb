class Tachikoma < Formula
  desc "Minimal macOS menu bar app for Tachikoma"
  homepage "https://github.com/s4na/tachikoma"
  head "https://github.com/s4na/tachikoma.git", branch: "main"

  depends_on :macos

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/tachikoma"
  end

  test do
    assert_match "Starts a minimal macOS menu bar app", shell_output("#{bin}/tachikoma --help")
  end
end
