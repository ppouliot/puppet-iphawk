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
  $hawk_user              = $iphawk::params::hawk_user,
  $hawk_group             = $iphawk::params::hawk_group,
  $hawk_db_user           = $iphawk::params::hawk_db_user,
  $hawk_db_password       = $iphawk::params::hawk_db_password,
  $hawk_db_name           = $iphawk::params::hawk_db_name,
  $hawk_db_host           = $iphawk::params::hawk_db_host,
  $hawk_logfile           = $iphawk::params::hawk_logfile,
  $hawk_pid               = $iphawk::params::hawk_pid,
  $hawk_init_script       = $iphawk::params::hawk_init_script,
  $hawk_script_template   = $iphawk::params::hawk_script_template,
  $ping_frequency         = $iphawk::params::ping_frequency,
  $ping_timeout           = $iphawk::params::ping_timeout,
# Debug Level 1 = Default, 2 = Every Ping
  $debug_level            = $iphawk::params::debug_level,
  $php_fpm                = $iphawk::params::php_fpm,
  $php_fpm_service        = $iphawk::params::php_fpm_service,
  $php_fpm_www_conf       = $iphawk::params::php_fpm_www_conf,
  $perl_required_packages = $iphawk::params::perl_required_packages,
  $additional_networks    = {},
  $additional_gateways    = [],
) inherits iphawk::params {

  package { $php_fpm:
    ensure => latest,
  }

  service {$php_fpm_service:
    ensure  => running,
    require => Package[$php_fpm],
  }
  package { $perl_required_packages :
    ensure => latest,
  }
  user { $hawk_user :
    ensure     => file,
    comment    => 'IPHawk user',
    home       => '/srv/hawk',
    shell      => '/bin/bash',
    groups     => $hawk_group,
    password   => $hawk_db_password,
    managehome => true,
    require    => Class['nginx'],
  }
  if $::osfamily == 'Redhat' {
    file { '/srv/hawk' :
      ensure  => file,
      mode    => '0755',
      require => User[$hawk_user],
    }
  }
  class {'::nginx':}
  nginx::resource::vhost { $::fqdn:
    www_root             => '/srv/hawk/hawk-0.6/php',
    use_default_location => false,
#    vhost_cfg_append     => { autoindex => on },
  }
  nginx::resource::location{'/':
    ensure   => file,
    www_root => '/srv/hawk/hawk-0.6/php',
    vhost    => $::fqdn,
  }
  nginx::resource::location{'~ "\.php$"':
    ensure   => file,
    www_root => '/srv/hawk/hawk-0.6/php',
    vhost    => $::fqdn,
    fastcgi  => 'localhost:9000',
#    fastcgi_script       => '/scripts$fastcgi_script_name',
  }

  exec {'get-hawk-tarball':
    command => '/usr/bin/wget -cv http://downloads.sourceforge.net/project/iphawk/iphawk/Hawk%200.6/hawk-0.6.tar.gz -O - | /bin/tar -xz',
    creates => '/srv/hawk/hawk-0.6',
    cwd     => '/srv/hawk/',
    require => User[$hawk_user],
  }

  exec {'conf-fastcgi-nginx':
    #command => "/bin/sed -i '^listen = \/var\/run\/php5-fpm.sock/c\listen = 127.0.0.1:9000' /etc/php5/fpm/pool.d/www.conf",
    command => "/bin/sed -i \'\^listen = /var/run/php5-fpm.sock/c\ listen = 127.0.0.1:9000\' ${php_fpm_www_conf}",
    cwd     => '/etc/php5/fpm/pool.d',
    require => [
      Package[ $php_fpm],
      Class['::nginx']
    ],
    notify  => Service[$php_fpm_service],
    unless  => "/bin/grep '^listen = 127.0.0.1:9000' ${php_fpm_www_conf}",
  }
  file {'/srv/hawk/hawk.sql':
    ensure  => file,
    content => "CREATE TABLE ip (
  ip CHAR(16) NOT NULL default '0',
  hostname CHAR(255) default NULL,
  lastping INT(10) default NULL,
  PRIMARY KEY (ip),
  UNIQUE KEY ip (ip),
  KEY ip_2 (ip)
) ENGINE=MYISAM;
",
    owner   => $hawk_user,
    group   => $hawk_group,
    mode    => '0644',
    require => User[$hawk_user],
  }
  class {'::mysql::server':}
  mysql::db{ $hawk_db_name:
    user     => $hawk_db_user,
    password => $hawk_db_password,
    host     => $hawk_db_host,
    grant    => ['CREATE','INSERT','SELECT','DELETE','UPDATE'],
    sql      => '/srv/hawk/hawk.sql',
    require  => [ File['/srv/hawk/hawk.sql'], Class['mysql::server'] ],
  }
  file {[
    '/srv/hawk/hawk-0.6',
    '/srv/hawk/hawk-0.6/php',
    '/srv/hawk/hawk-0.6/php/hawk.css',
    '/srv/hawk/hawk-0.6/php/hawk.php',
    '/srv/hawk/hawk-0.6/daemon']:
    ensure  => file,
    owner   => $hawk_user,
    group   => $hawk_group,
    mode    => '0644',
    require => Exec['get-hawk-tarball'],
  }
  file{'/srv/hawk/hawk-0.6/php/images':
    ensure  => file,
    recurse => true,
    owner   => $hawk_user,
    group   => $hawk_group,
    mode    => '0644',
    require => Exec['get-hawk-tarball'],
  }
  file {'/srv/hawk/hawk-0.6/php/index.php':
    ensure  => file,
    owner   => $hawk_user,
    group   => $hawk_group,
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
    ensure  => file,
    owner   => $hawk_user,
    group   => $hawk_group,
    mode    => '0755',
    require => Exec['get-hawk-tarball'],
  }
  file {'/srv/hawk/hawk-0.6/daemon/hawk.conf':
    ensure  => file,
    owner   => $hawk_user,
    group   => $hawk_group,
    mode    => '0644',
    require => Exec['get-hawk-tarball'],
    content => template('iphawk/hawk.conf.erb'),
  }
  file {'/srv/hawk/hawk-0.6/php/hawk.conf.inc':
    ensure  => file,
    owner   => $hawk_user,
    group   => $hawk_group,
    mode    => '0644',
    require => Exec['get-hawk-tarball'],
    content => template('iphawk/hawk.conf.inc.erb'),
  }
#  file {'/etc/init/hawk.conf':
  file {$hawk_init_script:
    ensure  => file,
    owner   => $hawk_user,
    group   => $hawk_group,
#    mode    => '0644',
    mode    => '0755',
    require => [ Exec['get-hawk-tarball'], File['/srv/hawk/hawk-0.6/daemon']],
    content => template($hawk_script_template),
  }
  service {'hawk':
    ensure  => running,
    require => File[$hawk_init_script,'/srv/hawk/hawk-0.6/daemon/hawk'],
  }
#  create_reasources(hawk_networks,$networks)
}
