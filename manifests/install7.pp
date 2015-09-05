# jdk7::instal7
#
# On Linux low entropy can cause certain operations to be very slow.
# Encryption operations need entropy to ensure randomness. Entropy is
# generated by the OS when you use the keyboard, the mouse or the disk.
#
# If an encryption operation is missing entropy it will wait until
# enough is generated.
#
# three options
#  use rngd service (this class)
#  set java.security in JDK ( jre/lib/security )
#  set -Djava.security.egd=file:/dev/./urandom param
#
define jdk7::install7 (
  $version                     = '7u79',
  $full_version                = 'jdk1.7.0_79',
  $java_homes                  = '/usr/java',
  $x64                         = true,
  $alternatives_priority       = 17065,
  $download_dir                = '/install',
  $cryptography_extension_file = undef,
  $urandom_java_fix            = true,
  $rsa_key_size_fix            = false,  # set true for weblogic 12.1.1 and jdk 1.7 > version 40
  $source_path                 = 'puppet:///modules/jdk7/',
) {

  if ( $x64 == true ) {
    $type = 'x64'
  } else {
    $type = 'i586'
  }

  case $::kernel {
    'Linux': {
      $install_version   = 'linux'
      $install_extension = '.tar.gz'
      $path              = '/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:'
      $user              = 'root'
      $group             = 'root'
    }
    default: {
      fail("Unrecognized operating system ${::kernel}, please use it on a Linux host")
    }
  }

  $jdk_file = "jdk-${version}-${install_version}-${type}${install_extension}"

  exec { "create ${download_dir} directory":
    command => "mkdir -p ${download_dir}",
    unless  => "test -d ${download_dir}",
    path    => $path,
    user    => $user,
  }

  # check install folder
  if !defined(File[$download_dir]) {
    file { $download_dir:
      ensure  => directory,
      require => Exec["create ${download_dir} directory"],
      replace => false,
      owner   => $user,
      group   => $group,
      mode    => '0777',
    }
  }

  # download jdk to client
  file { "${download_dir}/${jdk_file}":
    ensure  => file,
    source  => "${source_path}/${jdk_file}",
    require => File[$download_dir],
    replace => false,
    owner   => $user,
    group   => $group,
    mode    => '0777',
  }

  if ( $cryptography_extension_file != undef ) {
    file { "${download_dir}/${cryptography_extension_file}":
      ensure  => file,
      source  => "${source_path}/${cryptography_extension_file}",
      require => File[$download_dir],
      before  => File["${download_dir}/${jdk_file}"],
      replace => false,
      owner   => $user,
      group   => $group,
      mode    => '0777',
    }
  }

  # install on client
  jdk7::config::javaexec { "jdkexec ${title} ${version}":
    download_dir                => $download_dir,
    full_version                => $full_version,
    java_homes_dir              => $java_homes,
    jdk_file                    => $jdk_file,
    cryptography_extension_file => $cryptography_extension_file,
    alternatives_priority       => $alternatives_priority,
    user                        => $user,
    group                       => $group,
    require                     => File["${download_dir}/${jdk_file}"],
  }

  if ($urandom_java_fix == true) {
    exec { "set urandom ${full_version}":
      command => "sed -i -e's/^securerandom.source=.*/securerandom.source=file:\\/dev\\/.\\/urandom/g' ${java_homes}/${full_version}/jre/lib/security/java.security",
      unless  => "grep '^securerandom.source=file:/dev/./urandom' ${java_homes}/${full_version}/jre/lib/security/java.security",
      require => Jdk7::Config::Javaexec["jdkexec ${title} ${version}"],
      path    => $path,
      user    => $user,
    }
  }
  if ($rsa_key_size_fix == true) {
    exec { "sleep 3 sec for urandomJavaFix ${full_version}":
      command => '/bin/sleep 3',
      unless  => "grep 'RSA keySize < 512' ${java_homes}/${full_version}/jre/lib/security/java.security",
      require => Jdk7::Config::Javaexec["jdkexec ${title} ${version}"],
      path    => $path,
      user    => $user,
    }
    exec { "set RSA keySize ${full_version}":
      command     => "sed -i -e's/RSA keySize < 1024/RSA keySize < 512/g' ${java_homes}/${full_version}/jre/lib/security/java.security",
      unless      => "grep 'RSA keySize < 512' ${java_homes}/${full_version}/jre/lib/security/java.security",
      subscribe   => Exec["sleep 3 sec for urandomJavaFix ${full_version}"],
      refreshonly => true,
      path        => $path,
      user        => $user,
    }
  }
}
