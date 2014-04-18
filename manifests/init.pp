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
class iphawk (

#  $hawk_password = '$h@wk'
  $hawk_db_user     = $iphawk::params::hawk_db_user,
  $hawk_db_password = $iphawk::params::hawk_db_password,
  $hawk_db_name     = $iphawk::params::hawk_db_name,
  $hawk_db_host     = $iphawk::params::hawk_db_host,
  $hawk_logfile     = $iphawk::params::hawk_logfile,
  $hawk_pid         = $iphawk::params::hawk_pid,
  $ping_frequency   = $iphawk::params::ping_frequency,
  $ping_timeout     = $iphawk::params::ping_timeout,
# Debug Level 1 = Default, 2 = Every Ping
  $debug_level      = $iphawk::params::debug_level,
) inherits iphawk::params {

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
    groups     => 'www-data',
    password   => $hawk_db_password,
    managehome => true,
  }

  class {'nginx':}

  nginx::resource::vhost { 'hawk.openstack.tld':
    www_root             => '/srv/hawk/hawk-0.6/php',
#    fastcgi              => 'localhost:9000',
#    fastcgi_script       => '/scripts$fastcgi_script_name',
    use_default_location => false,
#    index_files => ['index.php','index.html'],
    vhost_cfg_append => {
      autoindex => on,
    }
  }
  nginx::resource::location{'/':
    ensure => present,
    www_root => '/srv/hawk/hawk-0.6/php',
    vhost    => $fqdn,
  }
  nginx::resource::location{'~ "\.php$"':
    ensure => present,
    www_root => '/srv/hawk/hawk-0.6/php',
    vhost    => $fqdn,
    fastcgi              => 'localhost:9000',
#    fastcgi_script       => '/scripts$fastcgi_script_name',
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

  mysql::db {$hawk_db_name:
    user     => $hawk_db_user,
    password => $hawk_db_password,
    host     => $hawk_db_host,
    grant    => ['CREATE','INSERT','SELECT','DELETE','UPDATE'],
    sql      => '/srv/hawk/hawk.sql',
    require  => [File['/srv/hawk/hawk.sql'],Class['mysql::server']],
  }
  file {['/srv/hawk/hawk-0.6',
         '/srv/hawk/hawk-0.6/php',
         '/srv/hawk/hawk-0.6/php/hawk.css',
         '/srv/hawk/hawk-0.6/php/hawk.php',
         '/srv/hawk/hawk-0.6/daemon']:
    ensure  => present,
    owner   => 'hawk',
    group   => 'hawk',
    mode    => '0644',
    require => Exec['get-hawk-tarball'],
  }
  file{'/srv/hawk/hawk-0.6/php/images':
    ensure  => present,
    recurse => true,
    owner   => 'hawk',
    group   => 'hawk',
    mode    => '0644',
    require => Exec['get-hawk-tarball'],
  }
  file {'/srv/hawk/hawk-0.6/php/index.php':
    ensure  => present,
    owner   => 'hawk',
    group   => 'hawk',
    mode    => '0644',
    source  => '/srv/hawk/hawk-0.6/php/hawk.php',
    require => Exec['get-hawk-tarball'],
  }
  exec {'fix_hawk_php_code':
    command   => "/bin/sed -i 's/HTTP_POST_VARS/_POST/g' /srv/hawk/hawk-0.6/php/index.php",
    cwd       => '/srv/hawk/hawk-0.6/php',
    require   => [Exec['get-hawk-tarball'],File['/srv/hawk/hawk-0.6/php/index.php']],
    unless    => '/bin/grep -vc "$_POST" /srv/hawk/hawk-0.6/php/index.php',
    logoutput => true,
  }
  
  file {'/srv/hawk/hawk-0.6/daemon/hawk':
    ensure  => present,
    owner   => 'hawk',
    group   => 'hawk',
    mode    => '0755',
    require => Exec['get-hawk-tarball'],
  }


  file {'/srv/hawk/hawk-0.6/daemon/hawk.conf':
    ensure => file,
    owner => 'hawk',
    group => 'hawk',
    mode  => '0644',
    require => Exec['get-hawk-tarball'],
    content => template('iphawk/hawk.conf.erb'),
  }
  file {'/srv/hawk/hawk-0.6/php/hawk.conf.inc':
    ensure => file,
    owner => 'hawk',
    group => 'hawk',
    mode  => '0644',
    require => Exec['get-hawk-tarball'],
    content => template('iphawk/hawk.conf.inc.erb'),
  }
  file {'/etc/init/hawk.conf':
    ensure => file,
    owner => 'hawk',
    group => 'hawk',
    mode  => '0644',
    require => [Exec['get-hawk-tarball'],File['/srv/hawk/hawk-0.6/daemon']],
    content => template('iphawk/hawk.conf.upstart.erb'),
  }

  service {'hawk':
    ensure => running,
    require => File['/etc/init/hawk.conf','/srv/hawk/hawk-0.6/daemon/hawk'],
  }   
#  create_reasources(hawk_networks,$networks)
}
