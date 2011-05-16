define redis::install() {
  $version = $name
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
}
