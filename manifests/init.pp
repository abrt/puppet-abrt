# Use puppet master host as default $foreman_proxy_host as it's most likely
# going to be the same machine.
class abrt (
  $foreman_proxy_host = $servername,
  $foreman_proxy_port = 9090,
  $ssl_cert_path = '/etc/pki/consumer/cert.pem',
  $ssl_key_path = '/etc/pki/consumer/key.pem',
  $foreman_proxy_ca_file = '/etc/rhsm/ca/katello-server-ca.pem',
) {

  if $foreman_proxy_host == '' {
    fail('Foreman proxy host not specified')
  }

  # Install and enable ABRT.
  package {'abrt-cli':
    ensure => present,
    allow_virtual => true,
  }

  service {'abrtd':
    ensure => running,
    enable => true,
    require => Package['abrt-cli'],
  }

  service {'abrt-ccpp':
    ensure => running,
    enable => true,
    require => Service['abrtd'],
  }

  # Enable automatic sending of reports.
  # No need to restart any service, ABRT will notice the files changed.
  augeas {'abrt_auto_reporting':
    context => '/files/etc/abrt/abrt.conf',
    changes => [
      'set AutoreportingEnabled yes',
    ],
    require => Package['abrt-cli'],
  }

  # Set the uReport server to the foreman proxy URL.
  augeas {'libreport_ureport_server':
    context => '/files/etc/libreport/plugins/ureport.conf',
    changes => [
      "set URL https://${foreman_proxy_host}:${foreman_proxy_port}/abrt",
      "set SSLClientAuth ${ssl_cert_path}:${ssl_key_path}",
    ],
    require => Package['abrt-cli'],
  }

  # Import the Foreman proxy certificate to the bundle of system certificates.
  file {'/etc/pki/ca-trust/source/anchors/foreman-proxy-ca.pem':
    ensure => present,
    source => $foreman_proxy_ca_file,
    notify => Exec['/usr/bin/update-ca-trust'],
  }

  exec {'/usr/bin/update-ca-trust':
    refreshonly => true,
  }
}
