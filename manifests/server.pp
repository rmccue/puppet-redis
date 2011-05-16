class redis::server($ensure=present,
                    $version='2.2.7',
                    $bind="127.0.0.1",
                    $port=6379,
                    $masterip="",
                    $masterport=6379,
                    $masterauth="",
                    $requirepass="",
                    $aof=false,
                    $aof_rewrite_hour=3,
                    $aof_rewrite_minute=30) {

  $is_present = $ensure == "present"
  $bin_dir = '/usr/local/bin'
  $redis_home = "/var/lib/redis"
  $redis_log = "/var/log/redis"

  class { "redis::overcommit":
    ensure => $ensure,
  }

  redis::install { $version:
    ensure => $ensure,
    bin_dir => $bin_dir,
  }

  file { "/etc/redis":
    ensure => $ensure ? {
      'present' => "directory",
      default => $ensure,
    },
  }

  file { "/etc/redis/redis.conf":
    content => template("redis/redis.conf.erb"),
    require => [Redis::Install[$version], File["/etc/redis"]],
  }

  if $ensure == 'present' {

    group { "redis":
      ensure => $ensure,
      allowdupe => false,
    }

    user { "redis":
      ensure => $ensure,
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
  } elsif $ensure == 'absent' {

    group { "redis":
      ensure => $ensure,
    }

    user { "redis":
      ensure => $ensure,
      before => Group["redis"],
    }

    file { [$redis_home, $redis_log]:
      ensure => $ensure,
      owner => "redis",
      group => "redis",
      recurse => true,
      purge => true,
      force => true,
      before => Group["redis"],
    }
  }

  file { "/etc/init.d/redis-server":
    ensure => $ensure,
    source => "puppet:///modules/redis/redis-server.init",
    mode => 744,
  }

  file { "/etc/logrotate.d/redis-server":
    ensure => $ensure,
    source => "puppet:///modules/redis/redis-server.logrotate",
  }

  service { "redis-server":
    ensure => $is_present,
    enable => $is_present,
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
      ensure => $ensure,
      command => "$redis_cli_prefix BGREWRITEAOF > /dev/null",
      hour => $aof_rewrite_hour,
      minute => $aof_rewrite_minute,
      require => Service["redis-server"],
    }
  }
}

