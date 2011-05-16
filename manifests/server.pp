class redis::server($version='2.2.5',
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
  $redis_src = "/usr/local/src/redis-${version}"

  @package { "build-essential":
    ensure => present,
  }

  realize(Package["build-essential"])

  file { $redis_src:
    ensure => "directory",
  }

  exec { "fetch redis ${version}": 
    command => "curl -sL https://github.com/antirez/redis/tarball/${version} | tar --strip-components 1 -xz",
    cwd => $redis_src,
    creates => "${redis_src}/Makefile",
    require => File[$redis_src],
  }

  exec { "install redis ${version}":
    command => "make && /etc/init.d/redis-server stop && make install PREFIX=/usr/local",
    cwd => "${redis_src}/src",
    unless => "test `redis-server --version | cut -d ' ' -f 4` = '${version}'",
    require => [Exec["fetch redis ${version}"], Package["build-essential"]]
  }

  $redis_home = "/var/lib/redis"
  $redis_log = "/var/log/redis"

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

  file { "/etc/redis":
    ensure => directory,
  }

  file { "/etc/redis/redis.conf":
    content => template("redis_server/redis.conf.erb"),
    require => [Exec["install redis ${version}"], File["/etc/redis"]],
  }

  file { "/etc/init.d/redis-server":
    source => "puppet:///modules/redis_server/redis-server.init",
    mode => 744,
  }

  file { "/etc/logrotate.d/redis-server":
    source => "puppet:///modules/redis_server/redis-server.logrotate",
  }

  service { "redis-server":
    ensure => running,
    enable => true,
    pattern => "${bin_dir}/redis-server",
    hasrestart => true,
    subscribe => [File["/etc/init.d/redis-server"],
                  File["/etc/redis/redis.conf"],
                  Exec["install redis ${version}"]],
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

