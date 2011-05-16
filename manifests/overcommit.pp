class redis::overcommit {

  file { "/etc/sysctl.d/overcommit.conf":
    content => "vm.overcommit_memory=1",
  }

  exec { "overcommit-memory":
    command => "sysctl vm.overcommit_memory=1",
    unless => "test `sysctl -n vm.overcommit_memory` = 1",
  }
}
