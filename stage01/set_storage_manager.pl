#!/usr/bin/perl
#use strict;
use Cwd;
use Digest::MD5  qw(md5_hex);

require "ec2ops.pl";

$ENV{'PWD'} = getcwd();

# does_It_Have( $arg1, $arg2 )
# does the string $arg1 have $arg2 in it ??
sub does_It_Have{
	my ($string, $target) = @_;
	if( $string =~ /$target/ ){
		return 1;
	};
	return 0;
};



#################### APP SPECIFIC PACKAGES INSTALLATION ##########################

my @ip_lst;
my @distro_lst;
my @source_lst;
my @roll_lst;

my %cc_lst;
my %sc_lst;
my %nc_lst;

my $clc_index = -1;
my $cc_index = -1;
my $sc_index = -1;
my $ws_index = -1;

my $clc_ip = "";
my $cc_ip = "";
my $sc_ip = "";
my $ws_ip = "";

my $nc_ip = "";

my $rev_no = 0;

my $max_cc_num = 0;

$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";

#### read the input list
print "\n";
print "Reading the Input File\n";
print "\n";

my $index = 0;

open( LIST, "../input/2b_tested.lst" ) or die "$!";

my $is_memo = 0;
my $memo = "";

my $line;
while( $line = <LIST> ){
	chomp($line);

	if( $is_memo ){
		if( $line ne "END_MEMO" ){
			$memo .= $line . "\n";
		}else{
			$is_memo = 0;
		};
	}elsif( $line =~ /^([\d\.]+)\s+(.+)\s+(.+)\s+(\d+)\s+(.+)\s+\[([\w\s\d]+)\]/ ){
		print "IP $1 with $2 distro is built from $5 as Eucalyptus-$6\n";
		push( @ip_lst, $1 );
		push( @distro_lst, $2 );
		push( @source_lst, $5 );
		push( @roll_lst, $6 );

		my $this_roll = $6;
               
		if( does_It_Have($this_roll, "CLC") && $clc_ip eq "" ){
			$clc_index = $index;
			$clc_ip = $1;
		};

		if( does_It_Have($this_roll, "CC") ){
			$cc_index = $index;
			$cc_ip = $1;

			if( $this_roll =~ /CC(\d+)/ ){
				$cc_lst{"CC_$1"} = $cc_ip;
				if( $1 > $max_cc_num ){
					$max_cc_num = $1;
				};
			};			
		};

		if( does_It_Have($this_roll, "SC") ){
			$sc_index = $index;
			$sc_ip = $1;

			if( $this_roll =~ /SC(\d+)/ ){
                            $sc_lst{"SC_$1"} = $sc_ip;
                        };
		};

		if( does_It_Have($this_roll, "WS") ){
                        $ws_index = $index;
                        $ws_ip = $1;
                };

		if( does_It_Have($this_roll, "NC") ){
                        #$nc_ip = $nc_ip . " " . $1;
			$nc_ip = $1;
			if( $this_roll =~ /NC(\d+)/ ){
				if( $nc_lst{"NC_$1"} eq	 "" ){
                                	$nc_lst{"NC_$1"} = $nc_ip;
				}else{
					$nc_lst{"NC_$1"} = $nc_lst{"NC_$1"} . " " . $nc_ip;
				};
                        };
                };


		$index++;
        }elsif( $line =~ /^BZR_REVISION\s+(\d+)/  ){
		$rev_no = $1;
		print "REVISION NUMBER is $rev_no\n";
	}elsif( $line =~ /^BZR_BRANCH\s+(.+)/ ){
			my $temp = $1;
			if( $temp =~ /eucalyptus\/(.+)/ ){
				$ENV{'QA_BZR_DIR'} = $1; 
			};
	}elsif( $line =~ /^TEST_NAME\s+(.+)/ ){
			print "\nTEST_NAME\t$1\n";
			$ENV{'QA_TEST_NAME'} = $1;
	}elsif( $line =~ /^UNIQUE_ID\s+(\d+)/ ){
			print "\nUNIQUE_ID\t$1\n";
			$ENV{'QA_UNIQUE_ID'} = $1;
	}elsif( $line =~ /^MEMO/ ){
		$is_memo = 1;
	}elsif( $line =~ /^END_MEMO/ ){
		$is_memo = 0;
	};
};

close( LIST );

$ENV{'QA_MEMO'} = $memo;

print "\n";

if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){
	$ENV{'EUCALYPTUS'} = "";
};

if( $rev_no == 0 ){
	print "Could not find the REVISION NUMBER\n";
};

if( $clc_ip eq "" ){
	print "Could not find the IP of CLC\n";
};

if( $cc_ip eq "" ){
        print "Could not find the IP of CC\n";
};

if( $sc_ip eq "" ){
        print "Could not find the IP of SC\n";
};

if( $ws_ip eq "" ){
        print "Could not find the IP of WS\n";
};

if( $nc_ip eq "" ){
        print "Could not find the IP of NC\n";
};

chomp($nc_ip);

### Download Admin Credentials
print "\n";
print "Downloading Admin Credentials\n";
print "\n";

print "$clc_ip :: rm -f /root/admin_cred.zip\n";
system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"rm -f /root/admin_cred.zip\" ");
sleep(1);

print "$clc_ip :: $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --get-credentials admin_cred.zip; unzip -o ./admin_cred.zip\n";
system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"cd /root; $ENV{'EUCALYPTUS'}/usr/sbin/euca_conf --get-credentials admin_cred.zip; unzip -o ./admin_cred.zip\" ");
sleep(5);

print "\n";

#Get partitions
%partitions;

$service="storage";

parse_input();
print "SUCCESS: parsed input\n";

setlibsleep(0);
print "SUCCESS: set sleep time for each lib call\n";

describe_services();
find_real_master("CLC");
describe_services();

open(fh, ">/tmp/ec2ops.out.$$");
print fh "$current_artifacts{master_ds_buf}\n";
close(fh);
$cmd = "cat /tmp/ec2ops.out.$$";
	 
($crc, $rc, $buf) = piperun($cmd, "egrep -e 'SERVICE[[:space:]]+$service' | grep $masters{SC00} | awk '{print \$3}' | head -n 1", "ubero");

if ($rc || $crc) {
    doexit(1, "FAILED: could not get partition name for $masters{SC00}\n");
}

$partitions{"SC00"}=$buf;

if($masters{'SC01'}) {
    ($crc, $rc, $buf) = piperun($cmd, "egrep -e 'SERVICE[[:space:]]+$service' | grep $masters{SC01} | awk '{print \$3}' | head -n 1", "ubero");

    if ($rc || $crc) {
        doexit(1, "FAILED: could not get partition name for $masters{SC01}\n");
    }
    $partitions{"SC01"}=$buf;
 } else {
    print "No SC01 found. Assuming this is not a multicluster setup.\n"
}


### Check SAN option
print "\n";
print "Checking SAN option in MEMO\n";
print "\n";

#Default is now OverlayManager, but that must be explicitly configured
my $ebs_storage_manager = "OverlayManager";

my $san_provider = "NO-SAN";

if( is_san_provider_from_memo() == 1 ){
	$san_provider = $ENV{'QA_MEMO_SAN_PROVIDER'};
};

if( is_ebs_storage_manager_from_memo() == 1){
	$ebs_storage_manager = $ENV{'QA_MEMO_EBS_STORAGE_MANAGER'};
};

print "\n";
print "ACTIONS:\n";
print "SAN_PROVIDER\t$san_provider\n";
print "EBS_STORAGE_MANAGER\t$ebs_storage_manager\n";
print "\n";

###	ADDED 011712
my $is_use_dev_san = 0;

if( is_use_dev_san_from_memo() == 1 ){
	$is_use_dev_san = 1;
	print "\n";
};

### ADDED for VNX support
my $md5_hex = md5_hex($ENV{'QA_TEST_NAME'});
my $test_id = substr($md5_hex,0,4) . "-" . $ENV{'QA_UNIQUE_ID'};

my $bzr = $ENV{'QA_BZR_DIR'};

#if( $bzr =~ /eee-2\.0/ ){

print "\n";
print "\n";
print "Checking the Version of Eucalyptus\n";
print "\n";

print "$clc_ip :: cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\n";
my $this_euca_version = `ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\"`;
chomp($this_euca_version);
print "Eucalyptus Version:\t$this_euca_version\n";

#Hard code badness for running new config for 3.2 code and later.
if($this_euca_version < "3.2") {
  print "[TEST_REPORT]\tOnly checking for DASManager setup because eucalyptus version is pre-3.2: $this_euca_version\n";
  #Check for DASManager, otherwise we do nothing for pre-3.2 code
  if( $ebs_storage_manager eq "DASManager" ){
    foreach $sc (keys(%partitions)) {
      #We need to make sure that /dev/sdb is clean.
      print "$sc_ip :: parted -s /dev/sdb rm 1\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$sc_ip \"parted -s /dev/sdb rm 1\" ");
      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.dasdevice=/dev/sdb\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.dasdevice=/dev/sdb\" ");
      sleep(1);
    };
    sleep(1);
    print "[TEST_REPORT]\tDAS Manager setup \'$ebs_storage_manager\' is completed\n";
  }
} else {
  print "[TEST REPORT]\tStorage Manager configuration beginning.\n";
  if( $ebs_storage_manager eq "DASManager" ) {

    foreach $sc (keys(%partitions)) {
      #We need to make sure that /dev/sdb is clean.
      print "$sc_ip :: parted -s /dev/sdb rm 1\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$sc_ip \"parted -s /dev/sdb rm 1\" ");
    
      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=das\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=das\" ");

      sleep(1);

      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.dasdevice=/dev/sdb\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.dasdevice=/dev/sdb\" ");
      sleep(1);
    };
    sleep(1);
    print "[TEST_REPORT]\tDAS Manager setup \'$ebs_storage_manager\' is completed\n";

  }elsif($san_provider eq "NO-SAN" and $ebs_storage_manager eq "OverlayManager") {
    #Setup OverlayManager by default if not specified as other
    foreach $sc (keys(%partitions)) {
      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=OverlayManager\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=overlay\" ");
      sleep(1);
	print "[TEST_REPORT]\tStorage Manager \'$ebs_storage_manager\' is completed\n";
    };
  }elsif( $san_provider eq "NetappProvider" ){

    foreach $sc (keys(%partitions)) {
      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=netapp\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=netapp\" ");
      sleep(1);
    };
    print "\n";

  }elsif( $san_provider eq "EquallogicProvider" ){

    foreach $sc (keys(%partitions)) {
      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=equallogic\n";
        system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=equallogic\" ");
	sleep(1);
    };
    print "\n";

  }elsif( $san_provider eq "EmcVnxProvider" ){

    foreach $sc (keys(%partitions)) {
      print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=emc-vnx\n";
      system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p $partitions{$sc}.storage.blockstoragemanager=emc-vnx\" ");
      sleep(1);
    };
    print "\n";
  }else{
    print "\n";
    print "[TEST_REPORT]\tStorage Manager setup is not specified\n";
    return 1;
  };
  print "[TEST_REPORT]\tStorage Manager \'$san_provider\' is completed\n";
  print "[TEST_REPORT]\tStorage Controller storagemanager setup for: \' $ebs_backend_manager \' and \'$san_provider\' is completed\n";
};
### TEMP SOL. to VLAN TAG issue	101311
print "\n";
print "\n";
print "Checking the Version of Eucalyptus\n";
print "\n";

print "$clc_ip :: cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\n";
my $this_euca_version = `ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\"`;
chomp($this_euca_version);
print "Eucalyptus Version\t$this_euca_version\n";
if( $this_euca_version =~ /^3/ ){
	print "\n";
	print "\n";
	print "Putting Limit on VLAN TAG range\n";
	print "\n";

	print "$clc_ip :: source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p cloud.network.global_max_network_tag=1000\n";
	system("ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$clc_ip \"source /root/eucarc; $ENV{'EUCALYPTUS'}/usr/sbin/euca-modify-property -p cloud.network.global_max_network_tag=1000\" ");
	sleep(1);
};


print "\n";
print "\n[TEST_REPORT]\tFinished set_storage_manager.pl\n";
print "\n";

exit(0);

1;



sub is_san_provider_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^SAN_PROVIDER=(.+)\n/m ){
		my $extra = $1;
		$extra =~ s/\r//g;
		print "FOUND in MEMO\n";
		print "SAN_PROVIDER=$extra\n";
		$ENV{'QA_MEMO_SAN_PROVIDER'} = $extra;
		return 1;
	};
	return 0;
};

sub is_ebs_storage_manager_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^EBS_STORAGE_MANAGER=(.+)\n/m ){
		my $extra = $1;
		$extra =~ s/\r//g;
		print "FOUND in MEMO\n";
		print "EBS_STORAGE_MANAGER=$extra\n";
		$ENV{'QA_MEMO_EBS_STORAGE_MANAGER'} = $extra;
		return 1;
	};
	return 0;
};


### ADDED 011712
sub is_use_dev_san_from_memo{
	if( $ENV{'QA_MEMO'} =~ /^USE_DEV_SAN=YES/m ){
		print "FOUND in MEMO\n";
		print "USE_DEV_SAN=YES\n";
		$ENV{'QA_MEMO_USE_DEV_SAN'} = "YES";
		return 1;
	};
	return 0;
};



1;

