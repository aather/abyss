#!/usr/bin/perl

package Setup;
#use strict;
#use warnings;

use Exporter;
our @ISA= qw( Exporter );
our @EXPORT_OK = qw( setup_filesystem );
our @EXPORT = qw( setup_filesystem );

# make sure user has permission to create file under requested mount point
$user=`id -nu`; $group=`id -ng`; chomp($user); chomp($group);

# subroutines
sub check_device;
sub create_filesystem;
sub mounted_device;
sub check_fstype;
sub try_umount;
sub try_mount;
sub check_md;
sub check_zpool;
sub create_md;
sub create_zpool;
sub zpool_size;
sub raid_size;
sub raid_matchdevs;
sub zpool_matchdevs;
sub create_raid;

sub setup_filesystem {
 my ($filesystem, $mpt, @devices) = @_;
    shift; shift;
 my $devicesref = shift;
 my @devices = @{$devicesref};

 my $supportedfs = "xfs,ext4,zfs,nfs";

 my $checkdisk; 
 my $mydfs;
 my $mydisk;
 my $mydmpt;
 my $checkmpt; 
 my @tri; 
 my $myfs;
 my @mydev; 

 # Check for invalid device and unsupported filesystem
 foreach my $dev (@devices) {
   if (($dev =~ /pool/) && ($filesystem !~ /zfs/)){
     print "You cannot create $filesystem on zpool. Only zfs\n"; 
     print "Exiting..";
     exit;
   }
   elsif ($dev !~ /pool/){
    if((! -e "/dev/$dev") && ($filesystem !~ /nfs/)){
        print "Invalid device:/dev/$dev\n";
        print "Exiting..";
        exit;
      }
    }
 }
 if ($supportedfs !~ /$filesystem/){
   print "Unsupported file system: $filesystem \n";
   print "Exiting..";
   exit;
 }

 # Check if requested mount point $mpt is in the mounted list. 
 $checkmpt = `df -T|grep /$mpt`;
 if ($checkmpt) {
   @tri = split /\s+/, $checkmpt;
   $myfs = $tri[1];
   @mydev = split /\//, $tri[0];   # device. Remove / from array
   $mympt = $tri[-1];
   $mympt =~ s/\///g;    # mount point. Remove / from string 
 }
 # Check if requested devices @devices is in the mounted list 
 if ($#devices == 0){
  $checkdisk = `df -T|grep @devices`;
  if ($checkdisk) {
    @tri = split /\s+/, $checkdisk;
    $mydfs = $tri[1];
    @mydisk = split /\//, $tri[0];   # device. Remove / from array
    $mydmpt = $tri[-1];
    $mydmpt =~ s/\///g;    # mount point. Remove / from string 
  }
 }

# Mount requested device(s)
 if (($checkmpt) && ($myfs =~ /$filesystem/)){
    `sudo chown $user /$mpt`;
    `sudo chgrp $group /$mpt`;
   print "NFS Case: All Matched. Ready to run Tests\n";
 }

 elsif (($checkmpt) && ($#devices == 0) && (($mydev[2] =~ /@devices/) || ($tri[0] =~ /pool/)) && ($myfs =~ /$filesystem/)){
   print "Mounted Case: All Matched. Ready to run Tests\n";
 } 

 elsif (($checkmpt) && ($#devices == 0) && (($mydev[2] =~ /@devices/) || ($tri[0] =~ /pool/)) && ($mympt =~ /$mpt/)){
   print "Request is to create a new file system: $filesystem on device:@devices \n";
   print "Umounting old file system: $myfs and creating a requested file system: $filesystem\n";
   try_umount($mympt,$myfs);
   create_filesystem($filesystem,$mpt,@devices);
   print "Ready to run Tests\n";
 } 

 elsif (($checkdisk) && ($#devices == 0) && (($mydisk[2] =~ /@devices/) || ($tri[0] =~ /pool/)) && ($mydfs =~ /$filesystem/)){ 
   print "Request is to change the mounted directory or mount point\n";
   print "umounting it from old directory $mydmpt and mounting it under a requested directory $mpt\n";
   try_umount($mydmpt, $mydfs);  
   try_mount($filesystem, @devices, $mpt);
   print "Ready to run Tests\n";
 }

 elsif (($checkdisk) && ($#devices == 0) && (($mydisk[2] =~ /@devices/) || ($tri[0] =~ /pool/))){ 
   print "Device is found in mounted list but mounted under differet mount point:$mydmpt\n";
   print "Umount it and create a file system on a new requested device\n";
   try_umount($mydmpt, $mydfs);  
   create_filesystem($filesystem,$mpt, @devices);
   print "Ready to run Tests\n";
 }

# Device is not found in mounted device list.
# Single Device case
 elsif ($#devices == 0){
   print "Single Device Case. Checking filesystem or raid or zpool on device.. :$mpt\n";
   if (check_fstype($filesystem, \@devices)){ 
     try_umount($mpt,$mydfs);
     try_mount($filesystem,@devices,$mpt);
   }
   elsif (check_zpool(@devices)){ 
     `sudo zpool destroy pool`;
     create_filesystem($filesystem,$mpt, @devices);
   }
   elsif(check_raid(@devices)){ 
      try_umountdev("/dev/md0", $mydfs); 
      `sudo mdadm --stop /dev/md0`; 
       create_filesystem($filesystem,$mpt, @devices);
   }
   else { 
     try_umountdev(@devices);
     create_filesystem($filesystem,$mpt, @devices);
  }
 } 

# Multiple Device case 

 elsif ($#devices > 0){
       print "Multiple Device Case: Check if devices have zpool and fs is zfs\n";
       if(zpool_matchdevs(\@devices)){ 
          if ($filesystem =~ /zfs/) { 
	   `sudo umount /pool`;    
           try_mount($filesystem,"pool",$mpt);
          }
          else{ 
            `sudo umount /pool`;
            `sudo zpool destroy pool`;
             create_raid(\@devices);
    	     create_filesystem($filesystem,$mpt,"md0"); 
	  }
       }
       elsif(raid_matchdevs(\@devices)){
          if (($filesystem =~ /ext4/) || ($filesystem =~ /xfs/)){ 
	    my @devices = ("md0");
            if (!check_fstype($filesystem,\@devices)){ 
	      try_umountdev("/dev/md0");
              create_filesystem($filesystem,$mpt,"md0");
	    }
          }
         else{ 
	      try_umountdev("/dev/md0");
             `sudo mdadm --stop /dev/md0`;
	      create_zpool($mpt,\@devices);
          } 
      }
      else{ 
       foreach my $dev (@devices){ 
          if (check_zpool($dev)){ 
	   `sudo zpool destroy pool`;
	    break;
	  }
          if (check_raid($dev)){ 
	    try_umountdev("/dev/md0");
	    `sudo mdadm --stop /dev/md0`;
	    break;
	  }
       }
       if (($filesystem =~ /ext4/) || ($filesystem =~ /xfs/)){
          create_raid(\@devices);
          create_filesystem($filesystem, $mpt,"md0");
       }
       elsif($filesystem =~ /zfs/){ 
	  create_zpool($mpt,\@devices);
       }
     }
  }
}


sub mounted_device {
  my ($dev) = @_;
  my $checkdev = `df -T|grep $dev`;
  if($checkdev){
    @tri = split /\s+/, $checkdev;
    $mympt = $tri[-1];
    $mympt =~ s/\///g;    # mounted directory. Remove / from string 
    @mydev = split /\//, $tri[0];   # mounted device. Remove / from array  

    if ($mydev[2] =~ /$dev/){
      return 1;
     }
    else {
      return 0;
    }
  }
}

sub check_fstype {
  my ($filesystem, @devices) = @_;
  shift;
  my $devicesref = shift;
  my @devices = @{$devicesref};
  my $ftype;
  my $found;

  print "check_fstype: filesystem $filesystem on device @devices\n";
  foreach my $dev (@devices){
     $ftype = `sudo file -sL /dev/$dev`; 
     $ftype = lc $ftype;  
     if (($ftype =~ /$filesystem/) && (($filesystem =~ /ext4/) || ($filesytem =~ /xfs/))){
       $found = $found + 1;
     }
    elsif (($ftype =~ /x86 boot sector/) && ($filesystem =~ /zfs/)){
	$found = $found + 1;
    }
   }
  return $found;
}

sub check_raid {
  my ($dev) = @_;

  if (! -e "/dev/md0") {
    return 0; 
  }

  if ($dev =~ /md/){
   return 0;
  }

  my $check_dev = `sudo cat /proc/mdstat|grep $dev`;
  if ($check_dev){ 
    return 1;
  }
  else {
    return 0;
  }
} 

sub check_zpool {
  my ($dev) = @_;

 if ($dev =~ /pool/){
   return 0;
  }
  my $zpexist = `sudo zpool status 2>&1`;
  if ($zpexist =~ /no pools available/){
     return 0;
  }

  my $check_dev = `sudo zpool status|grep $dev`;
  if ($check_dev){ 
    return 1
  }
  else {
   return 0;
  }
}

sub raid_size {
  my $mdstat = `cat /proc/mdstat`;
  my @mddisks = ();

  foreach my $disk (`cd /dev/;ls xv*`) {
    chomp($disk);
    if ($mdstat =~ /$disk/){
      push @mddisks, $disk;
    }
  }
  return ($#mdisks + 1);
}

sub zpool_size {
  my $zpstat = `sudo zpool status `;
  my @zpdisks = ();

  foreach my $disk (`cd /dev/;ls xv*`) {
    chomp($disk);
    if ($zpstat =~ /$disk/){
      push @zpdisks, $disk;
    }
  }
  return ($#zpdisks + 1);
}

sub create_filesystem {
  my ($filesystem,$mpt,$dev) = @_; 

  if ($filesystem =~ /xfs/){
    if (check_zpool($dev)){
      `sudo zpool destroy pool`;
    }
   `sudo /sbin/mkfs.xfs -K /dev/$dev -f `;
    try_mount($filesystem,$dev,$mpt);
  }
  elsif($filesystem =~ /ext4/){
    if (check_zpool($dev)){
      `sudo zpool destroy pool`;
    }
     `sudo /sbin/mkfs.ext4 -E nodiscard /dev/$dev`;
     try_mount($filesystem,$dev,$mpt);
  }
  elsif($filesystem =~ /zfs/){
        `sudo sudo zpool create -o ashift=12 -O compression=lz4 pool $dev -f`;
        `sudo zfs set mountpoint=/$mpt pool`;
        `sudo zfs set primarycache=metadata pool`;
        `sudo chown $user /$mpt`;
        `sudo chgrp $group /$mpt`;
  }
}

sub try_umount {
 my ($mympt, $mydfs) = @_;
 my $umount;
 my @pids;
 $umount = `sudo umount /$mympt 2>&1`;
 if ($umount =~ /busy/){ 
    print "File system is busy. Run lsof $mympt and kill these process\n";
    exit;
   }
}

sub try_umountdev {
 my ($dev) = @_;
 my $umount;
 my @pids;
 $umount = `sudo umount $dev 2>&1`;
 if ($umount =~ /busy/){
   print "File system is busy. check mount point of device $dev. Run lsof  and kill process\n";
   exit;
   }
}

sub try_mount {
 my ($filesystem, $dev, $mpt) = @_;

 if (-d "/$mpt"){  # if directory is created already
     `sudo rm /$mpt/*`;  # make sure directory is empty
     if ($filesystem =~ /xfs/){
       `sudo mount -o defaults,noatime,nobarrier /dev/$dev /$mpt`;
     }
     elsif ($filesystem =~ /ext4/){
       `sudo mount -o defaults,noatime,nobarrier,data=ordered /dev/$dev /$mpt`;
     }
     elsif ($filesystem =~ /zfs/){
       `sudo zfs mount pool`;
       `sudo zfs set mountpoint=/$mpt pool`;
       `sudo zfs set primarycache=metadata pool`;
     }
 }
 else{
      `sudo mkdir /$mpt`;
      if ($filesystem =~ /xfs/){
         `sudo mount -o defaults,noatime,nobarrier /dev/$dev /$mpt`;
      }
      elsif ($filesystem =~ /ext4/){
         `sudo mount -o defaults,noatime,nobarrier,data=ordered /dev/$dev /$mpt`;
      }
      elsif ($filesystem =~ /zfs/){
         `sudo zfs mount pool`;
         `sudo zfs set mountpoint=/$mpt pool`;
	 `sudo zfs set primarycache=metadata pool`;
      }
 }
 # Set the permission of mounted directory
 `sudo chown $user /$mpt`; 
 `sudo chgrp $group /$mpt`; 
}

sub raid_matchdevs{
  my ($devices) = @_;
 
  my $devicesref = shift;
  my @devices = @{$devicesref};

  my $mdstat = `cat /proc/mdstat`;
  my @mddisks = ();
  foreach my $disk (`cd /dev/;ls xv*`) {
    chomp($disk);
    if ($mdstat =~ /$disk/){
      push @mddisks, $disk;
    }
  }
  if (@mddisks ~~ @devices) {  
      return 1; 
  }
  else{  
      return 0 ; 
  }
}

sub zpool_matchdevs{
  my ($devices) = @_;

  my $devicesref = shift;
  my @devices = @{$devicesref};

  my $zpstat = `sudo zpool status`;
  my @zpdisks = ();
  foreach my $disk (`cd /dev/;ls xv*`) {
    chomp($disk);
    if ($zpstat =~ /$disk/){
      push @zpdisks, $disk;
    }
  }
  if (@zpdisks ~~ @devices) {
      return 1; 
  }
  else{
      return 0 ;
  }

}

sub create_raid {
 my ($devices) = @_;

 my $devicesref = shift;
 my @devices = @{$devicesref};

 my @disks = ();
 my $mdisks = ($#devices + 1);
 my $str;
 foreach my $dev (@devices){
  `sudo umount /dev/$dev`;
  $str = join "/","", "dev",$dev;    # This will create /dev/xvdb ..
  push @disks, $str;
  } 
 print "Creating Raid ...\n"; 
 `yes|sudo mdadm --create /dev/md0 --level 0 --chunk=64 --metadata=1.1 --raid-devices=$mdisks @disks`
}

sub create_zpool {
 my ($mpt, $devices) = @_;
 shift;
 my $devicesref = shift;
 my @devices = @{$devicesref};
 
 foreach my $dev (@devices){
  `sudo umount /dev/$dev`;
 }
 print "Creating zpool ...\n"; 
 `sudo sudo zpool create -o ashift=12 -O compression=lz4 pool @devices -f`;
 `sudo zfs set mountpoint=/$mpt pool`;
 `sudo zfs set primarycache=metadata pool`;
 `sudo chown $user /$mpt`;
 `sudo chgrp $group /$mpt`;

}
1;

