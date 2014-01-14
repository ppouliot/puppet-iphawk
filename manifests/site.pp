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
    content => template('modules/iphawk/hawk.conf.erb'),
  }
}
