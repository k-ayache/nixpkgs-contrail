{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cassandra;

  cassandraPkg = pkgs.cassandra_3_0.overrideAttrs (oldAttrs: {
    name = "cassandra-3.11.1";
    src = pkgs.fetchurl {
      sha256="1vgh4ysnl4xg8g5v6zm78h3sq308r7s17ppbw0ck4bwyfnbddvkg";
      url = "mirror://apache/cassandra/3.11.1/apache-cassandra-3.11.1-bin.tar.gz";
    };
  });

  cassandraConfigDir = pkgs.runCommand "cassandraConfDir" {} ''
    mkdir -p $out
    cat ${cassandraPkg}/conf/cassandra.yaml > $out/cassandra.yaml
    cat >> $out/cassandra.yaml << EOF
    data_file_directories:
        - /tmp/cassandra-data/data
    commitlog_directory:
        - /tmp/cassandra-data/commitlog
    saved_caches_directory:
        - /tmp/cassandra-data/saved_caches
    hints_directory:
        - /tmp/cassandra-data/hints
    start_rpc: true
    EOF

    cat >> $out/logback.xml << EOF
    <configuration scan="true">
      <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
        <file>/var/log/cassandra/system.log</file>
        <rollingPolicy class="ch.qos.logback.core.rolling.FixedWindowRollingPolicy">
          <fileNamePattern>/var/log/cassandra/system.log.%i.zip</fileNamePattern>
          <minIndex>1</minIndex>
          <maxIndex>20</maxIndex>
        </rollingPolicy>

        <triggeringPolicy class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy">
          <maxFileSize>20MB</maxFileSize>
        </triggeringPolicy>
        <encoder>
          <pattern>%-5level [%thread] %date{ISO8601} %F:%L - %msg%n</pattern>
          <!-- old-style log format
          <pattern>%5level [%thread] %date{ISO8601} %F (line %L) %msg%n</pattern>
          -->
        </encoder>
      </appender>

      <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%-5level %date{HH:mm:ss,SSS} %msg%n</pattern>
        </encoder>
      </appender>

      <root level="INFO">
        <appender-ref ref="FILE" />
        <appender-ref ref="STDOUT" />
      </root>

      <logger name="com.thinkaurelius.thrift" level="ERROR"/>
    </configuration>
    EOF
  '';

in {
  options = {
    services.cassandra = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      postStart = mkOption {
        type = types.lines;
        default = "";
      };
    };
  };
  config = mkIf cfg.enable {
    systemd.services.cassandra = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ cassandraPkg ];
      environment = {
        CASSANDRA_CONFIG = cassandraConfigDir;
      };
      script = ''
        mkdir -p /tmp/cassandra-data/
        chmod a+w /tmp/cassandra-data
        export CASSANDRA_CONF=${cassandraConfigDir}
        export JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.port=7199"
        export JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.ssl=false"
        export JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
        ${cassandraPkg}/bin/cassandra -f -R
      '';
      postStart = ''
        sleep 2
        while ! ${cassandraPkg}/bin/nodetool status >/dev/null 2>&1; do
          sleep 2
        done

        ${cfg.postStart}
      '';
    };
  };
}
