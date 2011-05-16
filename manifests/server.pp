class redis::server($version='2.2.7',
                    $bind="127.0.0.1",
                    $port=6379,
                    $masterip="",
                    $masterport=6379,
                    $masterauth="",
                    $requirepass="",
                    $aof=false,
                    $aof_rewrite_hour=3,
                    $aof_rewrite_minute=30) {

  $bin_dir = '/usr/local/bin'
  $redis_home = "/var/lib/redis"
  $redis_log = "/var/log/redis"

  include redis::overcommit

  redis::install { $version: }

  file { "/etc/redis":
    ensure => directory,
  }

  file { "/etc/redis/redis.conf":
    content => template("redis/redis.conf.erb"),
    require => [Redis::Install[$version], File["/etc/redis"]],
  }

  group { "redis":
    ensure => present,
    allowdupe => false,
  }

  user { "redis":
    ensure => present,
    allowdupe => false,
    home => $redis_home,
    managehome => true,
    gid => "redis",
    shell => "/bin/false",
    comment => "Redis Server",
    require => Group["redis"],
  }

  file { [$redis_home, $redis_log]:
    ensure => directory,
    owner => "redis",
    group => "redis",
    require => User["redis"],
  }

  file { "/etc/init.d/redis-server":
    source => "puppet:///modules/redis/redis-server.init",
    mode => 744,
  }

  file { "/etc/logrotate.d/redis-server":
    source => "puppet:///modules/redis/redis-server.logrotate",
  }

  service { "redis-server":
    ensure => running,
    enable => true,
    pattern => "${bin_dir}/redis-server",
    hasrestart => true,
    subscribe => [File["/etc/init.d/redis-server"],
                  File["/etc/redis/redis.conf"],
                  Redis::Install[$version],
                  Class["redis::overcommit"]],
  }

  $redis_cli_prefix = $requirepass ? {
      "" => "redis-cli -h $bind -p $port",
      default => "redis-cli -h $bind -p $port -a '${requirepass}'",
  }

  if $aof {
    cron { "rewrite-aof":
      command => "$redis_cli_prefix BGREWRITEAOF > /dev/null",
      hour => $aof_rewrite_hour,
      minute => $aof_rewrite_minute,
      require => Service["redis-server"],
    }
  }
}

