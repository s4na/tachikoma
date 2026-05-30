# frozen_string_literal: true

# Homebrew formula for Tachikoma.
class Tachikoma < Formula
  LAUNCH_AGENT_LABEL = "com.s4na.tachikoma"

  desc "Minimal macOS menu bar app for Tachikoma"
  homepage "https://github.com/s4na/tachikoma"
  url "https://github.com/s4na/tachikoma/archive/refs/tags/v0.1.5.tar.gz"
  sha256 "ceb9254967b02092befd95c7d0d669cc6834933a948806d2c9f57a82236809a3"
  head "https://github.com/s4na/tachikoma.git", branch: "main"

  depends_on macos: :ventura

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/tachikoma"
  end

  service do
    name macos: LAUNCH_AGENT_LABEL
    run [opt_bin/"tachikoma"]
    process_type :interactive
    run_at_load true
  end

  def post_install
    launch_agent_path.dirname.mkpath
    rm_f launch_agent_path
    cp launchd_service_path, launch_agent_path
    chmod 0644, launch_agent_path

    launchctl_bootout
    launchctl_bootstrap
    launchctl_kickstart
  end

  def caveats
    <<~EOS
      Tachikoma starts in the background after installation and at login.
      You can disable future login startup from Tachikoma's menu bar settings.
    EOS
  end

  test do
    assert_match "syncs its login startup setting", shell_output("#{bin}/tachikoma --help")
  end

  private

  def launch_agent_path
    Pathname.new("~/Library/LaunchAgents/#{LAUNCH_AGENT_LABEL}.plist").expand_path
  end

  def launchctl_domain
    "gui/#{Process.uid}"
  end

  def launchctl_service
    "#{launchctl_domain}/#{LAUNCH_AGENT_LABEL}"
  end

  def launchctl_bootout
    quiet_system "/bin/launchctl", "bootout", launchctl_service
  end

  def launchctl_bootstrap
    system "/bin/launchctl", "bootstrap", launchctl_domain, launch_agent_path
  end

  def launchctl_kickstart
    system "/bin/launchctl", "kickstart", "-k", launchctl_service
  end
end
