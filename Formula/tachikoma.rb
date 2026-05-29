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

  service do
    run opt_bin/"tachikoma"
  end

  test do
    assert_match "Starts a minimal macOS menu bar app", shell_output("#{bin}/tachikoma --help")
  end
end
