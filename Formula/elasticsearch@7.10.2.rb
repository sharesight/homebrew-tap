class ElasticsearchAT7102 < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  # NOTE: Do not bump version to one with a non-open-source license
  url "https://github.com/elastic/elasticsearch/archive/v7.10.2.tar.gz"
  sha256 "bdb7811882a0d9436ac202a947061b565aa71983c72e1c191e7373119a1cdd1c"
  license "Apache-2.0"

  # elasticsearch will be relicensed before v7.11.
  # https://www.elastic.co/blog/licensing-change
  deprecate! date: "2021-01-14", because: "is switching to an incompatible license. Check out `opensearch` instead"

  depends_on "gradle@6" => :build
  depends_on "openjdk"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end

  def install
    os = OS.kernel_name.downcase
    system "gradle", ":distribution:archives:oss-no-jdk-#{os}-tar:assemble"

    mkdir "tar" do
      # Extract the package to the tar directory
      system "tar", "--strip-components=1", "-xf",
        Dir["../distribution/archives/oss-no-jdk-#{os}-tar/build/distributions/elasticsearch-oss-*.tar.gz"].first

      # Install into package directory
      libexec.install "bin", "lib", "modules"

      # Set up Elasticsearch for local development:
      inreplace "config/elasticsearch.yml" do |s|
        # 1. Give the cluster a unique name
        s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")

        # 2. Configure paths
        s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/elasticsearch/")
        s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/elasticsearch/")
      end

      inreplace "config/jvm.options", %r{logs/gc.log}, "#{var}/log/elasticsearch/gc.log"

      # Move config files into etc
      (etc/"elasticsearch").install Dir["config/*"]
    end

    inreplace libexec/"bin/elasticsearch-env",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"$ES_HOME\"/config; fi",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"#{etc}/elasticsearch\"; fi"

    bin.install libexec/"bin/elasticsearch",
                libexec/"bin/elasticsearch-keystore",
                libexec/"bin/elasticsearch-plugin",
                libexec/"bin/elasticsearch-shard"
    bin.env_script_all_files libexec/"bin", Language::Java.overridable_java_home_env
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/elasticsearch").mkpath
    (var/"log/elasticsearch").mkpath
    ln_s etc/"elasticsearch", libexec/"config" unless (libexec/"config").exist?
    (var/"elasticsearch/plugins").mkpath
    ln_s var/"elasticsearch/plugins", libexec/"plugins" unless (libexec/"plugins").exist?
    # fix test not being able to create keystore because of sandbox permissions
    system bin/"elasticsearch-keystore", "create" unless (etc/"elasticsearch/elasticsearch.keystore").exist?
  end

  def caveats
    <<~EOS
      Data:    #{var}/lib/elasticsearch/
      Logs:    #{var}/log/elasticsearch/#{cluster_name}.log
      Plugins: #{var}/elasticsearch/plugins/
      Config:  #{etc}/elasticsearch/
    EOS
  end

  service do
    run opt_bin/"elasticsearch"
    require_root false
    working_dir var
    log_path var/"elasticsearch.log"
    error_log_path var/"elasticsearch.log"
    environment_variables ES_JAVA_HOME: "/Library/Java/JavaVirtualMachines/jdk-11.0.11.jdk/Contents/Home"
  end

  test do
    port = free_port
    (testpath/"data").mkdir
    (testpath/"logs").mkdir
    fork do
      exec bin/"elasticsearch", "-Ehttp.port=#{port}",
                                "-Epath.data=#{testpath}/data",
                                "-Epath.logs=#{testpath}/logs"
    end
    sleep 20
    output = shell_output("curl -s -XGET localhost:#{port}/")
    assert_equal "oss", JSON.parse(output)["version"]["build_flavor"]

    system "#{bin}/elasticsearch-plugin", "list"
  end
end
