class RedisAT724 < Formula
  desc "Persistent key-value database, with built-in net interface"
  homepage "https://redis.io/"
  url "https://download.redis.io/releases/redis-7.2.4.tar.gz"
  sha256 "8d104c26a154b29fd67d6568b4f375212212ad41e0c2caa3d66480e78dbd3b59"
  license "BSD-3-Clause"
  head "https://github.com/redis/redis.git", branch: "unstable"

  livecheck do
    url "https://download.redis.io/releases/"
    regex(/href=.*?redis[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  keg_only "it conflicts with redis and the other Redis versions in this tap"

  depends_on "openssl@3"

  def install
    system "make", "install", "PREFIX=#{prefix}", "CC=#{ENV.cc}", "BUILD_TLS=yes"

    # Keep config, data, pid and log files separate from the other Redis versions in this tap
    %w[run db/redis@7.2.4 log].each { |p| (var/p).mkpath }

    # Fix up default conf file to match our paths
    inreplace "redis.conf" do |s|
      s.gsub! "/var/run/redis_6379.pid", var/"run/redis@7.2.4.pid"
      s.gsub! "dir ./", "dir #{var}/db/redis@7.2.4/"
      s.sub!(/^bind .*$/, "bind 127.0.0.1 ::1")
    end

    (etc/"redis@7.2.4").install "redis.conf"
    (etc/"redis@7.2.4").install "sentinel.conf" => "redis-sentinel.conf"
  end

  service do
    run [opt_bin/"redis-server", etc/"redis@7.2.4/redis.conf"]
    keep_alive true
    error_log_path var/"log/redis@7.2.4.log"
    log_path var/"log/redis@7.2.4.log"
    working_dir var
  end

  test do
    system bin/"redis-server", "--test-memory", "2"
    %w[run db/redis@7.2.4 log].each { |p| assert_path_exists var/p, "#{var/p} doesn't exist!" }
  end
end
