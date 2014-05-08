class iphawk::params {
#  $hawk_password    = '$h@wk'
  $hawk_user        = 'hawk'
  $hawk_db_user     = 'hawk'
  #$hawk_db_password = hiera('hawk_db_password',{})
  $hawk_db_password = 'hard24get'
  $hawk_db_name     = 'hawk'
  $hawk_db_host     = 'localhost'
  $hawk_logfile     = '/var/log/hawk.log'
  $hawk_pid         = '/var/run/hawk.pid'
  $ping_frequency   = '0'
  $ping_timeout     = '2'
# Debug Level 1 = Default, 2 = Every Ping
  $debug_level      = '2'

  case $::osfamily {
    'Debian': {
      notify {'this is debian':}
      $hawk_group             = 'www-data'
      $php_fpm                = ['php5-fpm','php5-mysql']
      $php_fpm_service        = 'php5-fpm'
      $php_fpm_www_conf       = '/etc/php5/fpm/pool.d/www.conf'
      $perl_required_packages = ['libnet-netmask-perl',
'libnet-ping-perl',
'libclass-dbi-perl',
'libdbd-mysql-perl']
    }
    'Redhat':{
      notify {'this is redhat':}

      package {'rpmforge-release':
        ensure   => installed,
        provider => rpm,
        source   => 'http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el6.rf.x86_64.rpm',
        before   => Package['perl-Net-Netmask.noarch'],
      }


      $hawk_group             = 'nginx'
      $php_fpm                =  ['php-fpm','php-mysql']
      $php_fpm_service        = 'php-fpm'
      $php_fpm_www_conf       = '/etc/php-fpm.d/www.conf'
      $perl_required_packages = [ 'perl-Net-Netmask.noarch',
'perl-Class-DBI.noarch',
'perl-DBD-MySQL']
    }
#                                 'libnet-ping-perl',
    default: {
      notify {'unsupported':}
    }
  }
}
