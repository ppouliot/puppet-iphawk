# == Class: iphawk::params
class iphawk::params {
#  $hawk_password    = '$h@wk'
  $hawk_user        = 'hawk'
  $hawk_db_user     = 'hawk'
  $hawk_home_dir    = '/srv/hawk/hawk-0.6'
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
      $hawk_init_script       = '/etc/init/hawk.conf'
      $hawk_script_template   = 'iphawk/hawk.conf.upstart.erb'
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

      perl::cpan::module {'Net::Ping': }


      $hawk_group             = 'nginx'
      $hawk_init_script       = '/etc/init.d/hawk'
      $hawk_script_template   = 'iphawk/hawk.conf.initd.erb'
      $php_fpm                =  ['php-fpm','php-mysql']
      $php_fpm_service        = 'php-fpm'
      $php_fpm_www_conf       = '/etc/php-fpm.d/www.conf'
      $perl_required_packages = [ 'perl-Net-Netmask.noarch',
'perl-Class-DBI.noarch',
'perl-DBD-MySQL']
      
    }
    default: {
      notify {'unsupported':}
    }
  }
}
