# == Class: iphawk
#
# Full description of class iphawk here.
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the funtion of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { iphawk: }
#
# === Authors
#
# Peter J. Pouliot <peter@pouliot.net>
#
# === Copyright
#
# Copyright 2014 Peter J. Pouliot
#
class iphawk {

  package {'php5-fpm':
    ensure => latest,
  }

  service {'php5-fpm':
    ensure => running,
    require => Package['php5-fpm'],
  }

  package {['php5-mysql','libnet-netmask-perl','libnet-ping-perl','libclass-dbi-perl','libdbd-mysql-perl']:
    ensure => latest,
  }


  user {'hawk':
    ensure     => present,
    comment    => 'IPHawk user',
    home       => '/srv/hawk',
    shell      => '/bin/bash',
    password   => '$h@wk',
    managehome => true,
  }

  class {'nginx':}

  nginx::resource::vhost { 'hawk.openstack.tld':
    www_root    => '/srv/hawk/hawk-0.6/php',
    fastcgi     => 'localhost:9000',
    index_files => ['hawk.php','index.php','index.html'],
    vhost_cfg_append => {
      autoindex => on,
    }
  }

  exec {'get-hawk-tarball':
    command => '/usr/bin/wget -cv http://downloads.sourceforge.net/project/iphawk/iphawk/Hawk%200.6/hawk-0.6.tar.gz -O - | tar -xz',
    creates => '/srv/hawk/hawk-0.6',
    cwd     => '/srv/hawk/',
    require => User['hawk'],
  }

  exec {'conf-fastcgi-nginx':
    command => "/bin/sed -i '/^listen = \/var\/run\/php5-fpm.sock/c\listen = 127.0.0.1\:9000' /etc/php5/fpm/pool.d/www.conf",
    cwd     => '/etc/php5/fpm/pool.d',
    require => [Package['php5-fpm'],Class['nginx']],
    notify  => Service['php5-fpm'],
    unless  => "/bin/grep '^listen = 127.0.0.1\:9000' /etc/php5/fpm/pool.d/www.conf"
  }

  file {'/srv/hawk/hawk.sql':
    ensure => file,
    content => "CREATE TABLE ip (
  ip CHAR(16) NOT NULL default '0',
  hostname CHAR(255) default NULL,
  lastping INT(10) default NULL,
  PRIMARY KEY (ip),
  UNIQUE KEY ip (ip),
  KEY ip_2 (ip)
) ENGINE=MYISAM;
",
    owner => 'hawk',
    group => 'hawk',
    mode  => '0644',
    require => User['hawk'],
  }

  class {'::mysql::server':}

  mysql::db {'hawk':
    user     => 'hawk',
    password => '$h@wk',
    host     => 'localhost',
    grant    => ['CREATE','INSERT','SELECT','DELETE','UPDATE'],
    sql      => '/srv/hawk/hawk.sql',
    require  => [File['/srv/hawk/hawk.sql'],Class['mysql::server']],
  }

  file {'/srv/hawk/hawk.conf':
    ensure => file,
    owner => 'hawk',
    group => 'hawk',
    mode  => '0644',
    require => User['hawk'],
    content => template('iphawk/hawk.conf.erb'),
  }
}