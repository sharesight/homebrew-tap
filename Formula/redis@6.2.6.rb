class RedisAT626 < Formula
  desc "Persistent key-value database, with built-in net interface"
  homepage "https://redis.io/"
  url "https://download.redis.io/releases/redis-6.2.6.tar.gz"
  sha256 "5b2b8b7a50111ef395bf1c1d5be11e6e167ac018125055daa8b5c2317ae131ab"
  license "BSD-3-Clause"
  head "https://github.com/redis/redis.git", branch: "unstable"

  livecheck do
    url "https://download.redis.io/releases/"
    regex(/href=.*?redis[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  depends_on "openssl@3"

  # Fix build with recent macOS SDKs, which no longer provide stat64.
  # Backport of https://github.com/redis/redis/commit/2f27ebb414 (Redis 6.2.14).
  patch :DATA

  def install
    system "make", "install", "PREFIX=#{prefix}", "CC=#{ENV.cc}", "BUILD_TLS=yes"

    %w[run db/redis log].each { |p| (var/p).mkpath }

    # Fix up default conf file to match our paths
    inreplace "redis.conf" do |s|
      s.gsub! "/var/run/redis.pid", var/"run/redis.pid"
      s.gsub! "dir ./", "dir #{var}/db/redis/"
      s.sub!(/^bind .*$/, "bind 127.0.0.1 ::1")
    end

    etc.install "redis.conf"
    etc.install "sentinel.conf" => "redis-sentinel.conf"
  end

  service do
    run [opt_bin/"redis-server", etc/"redis.conf"]
    keep_alive true
    error_log_path var/"log/redis.log"
    log_path var/"log/redis.log"
    working_dir var
  end

  test do
    system bin/"redis-server", "--test-memory", "2"
    %w[run db/redis log].each { |p| assert_path_exists var/p, "#{var/p} doesn't exist!" }
  end
end

__END__
diff -ru a/src/config.h b/src/config.h
--- a/src/config.h
+++ b/src/config.h
@@ -39,8 +39,12 @@
 #include <fcntl.h>
 #endif
 
+#if defined(__APPLE__) && defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1060
+#define MAC_OS_10_6_DETECTED
+#endif
+
 /* Define redis_fstat to fstat or fstat64() */
-#if defined(__APPLE__) && !defined(MAC_OS_X_VERSION_10_6)
+#if defined(__APPLE__) && !defined(MAC_OS_10_6_DETECTED)
 #define redis_fstat fstat64
 #define redis_stat stat64
 #else
@@ -79,7 +83,7 @@
 #define HAVE_EPOLL 1
 #endif
 
-#if (defined(__APPLE__) && defined(MAC_OS_X_VERSION_10_6)) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
+#if (defined(__APPLE__) && defined(MAC_OS_10_6_DETECTED)) || defined(__FreeBSD__) || defined(__OpenBSD__) || defined (__NetBSD__)
 #define HAVE_KQUEUE 1
 #endif
 
@@ -248,7 +252,7 @@
 #include <kernel/OS.h>
 #define redis_set_thread_title(name) rename_thread(find_thread(0), name)
 #else
-#if (defined __APPLE__ && defined(MAC_OS_X_VERSION_10_7))
+#if (defined __APPLE__ && defined(__MAC_OS_X_VERSION_MAX_ALLOWED) && __MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
 int pthread_setname_np(const char *name);
 #include <pthread.h>
 #define redis_set_thread_title(name) pthread_setname_np(name)
diff -ru a/src/debug.c b/src/debug.c
--- a/src/debug.c
+++ b/src/debug.c
@@ -1020,7 +1020,7 @@
 
 #ifdef HAVE_BACKTRACE
 static void *getMcontextEip(ucontext_t *uc) {
-#if defined(__APPLE__) && !defined(MAC_OS_X_VERSION_10_6)
+#if defined(__APPLE__) && !defined(MAC_OS_10_6_DETECTED)
     /* OSX < 10.6 */
     #if defined(__x86_64__)
     return (void*) uc->uc_mcontext->__ss.__rip;
@@ -1029,7 +1029,7 @@
     #else
     return (void*) uc->uc_mcontext->__ss.__srr0;
     #endif
-#elif defined(__APPLE__) && defined(MAC_OS_X_VERSION_10_6)
+#elif defined(__APPLE__) && defined(MAC_OS_10_6_DETECTED)
     /* OSX >= 10.6 */
     #if defined(_STRUCT_X86_THREAD_STATE64) && !defined(__i386__)
     return (void*) uc->uc_mcontext->__ss.__rip;
@@ -1097,7 +1097,7 @@
     serverLog(LL_WARNING|LL_RAW, "\n------ REGISTERS ------\n");
 
 /* OSX */
-#if defined(__APPLE__) && defined(MAC_OS_X_VERSION_10_6)
+#if defined(__APPLE__) && defined(MAC_OS_10_6_DETECTED)
   /* OSX AMD64 */
     #if defined(_STRUCT_X86_THREAD_STATE64) && !defined(__i386__)
     serverLog(LL_WARNING,
