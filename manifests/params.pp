class iphawk::params {
#  $hawk_password = '$h@wk'
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
}
