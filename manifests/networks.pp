# == Class: iphawk::network
  # define iphawk::network::gateway 
  define iphawk::network::gateway () {
    concat::fragment{"additional_network_${name}":
      content => "${name},",
    }
  }

  # define iphawk::network::subnet
  define iphawk::network::subnet ( $network_address, $netmask_cidr ) {
    concat::fragment{"additional_network_${name}":
      content => "${network_address}/${netmask_cidr},",
    }
  }
}
