#!/usr/bin/perl

require "ec2ops.pl";

use Cwd;

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
} else {
	$ENV{'EUCALYPTUS'} = "/opt/eucalyptus";
} 


my $component = "SC00";
my $service = "storage";

parse_input();
print "SUCCESS: parsed input\n";

setlibsleep(0);
print "SUCCESS: set sleep time for each lib call\n";

describe_services();
find_real_master("CLC");

run_command("ssh -o StrictHostKeyChecking=no root\@$masters{CLC} 'cd /root; if ( test -f /root/admin_cred.zip ); then unzip -o /root/admin_cred.zip; fi'");
print "\n";
print "\n";
print "Checking the Version of Eucalyptus\n";
print "\n";
  
print "$masters{CLC} :: cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\n";
my $this_euca_version = `ssh -o ServerAliveInterval=1 -o ServerAliveCountMax=5 -o StrictHostKeyChecking=no root\@$masters{CLC} \"cat $ENV{'EUCALYPTUS'}/etc/eucalyptus/eucalyptus-version\"`;
 
chomp($this_euca_version);
print "Eucalyptus Version:\t$this_euca_version\n";
  
#Hard code badness for running new config for 3.2 code and later.
if(not $this_euca_version eq "" and $this_euca_version < "3.2") {
  print "[TEST_REPORT]\tSkipping waiting for service state transition to NOT_READY because eucalyptus version is pre-3.2: $this_euca_version\n";
  print "[TEST_REPORT]\texiting this test as a no-op.\n";
  exit(0);  
}

print "[TEST REPORT]\tWaiting for storage services to enter either NOT_READY or ENABLED state.\n";
for($i=0; $i <=24 ; $i++) {
  describe_services();
  find_real_master($component);
  print "MASTER: $masters{$component}\n";

  if($masters{$component}) {
        open(FH, ">/tmp/ec2ops.out.$$");
        print FH "$current_artifacts{master_ds_buf}\n";
        close(FH);
        $cmd = "cat /tmp/ec2ops.out.$$";
        ($crc, $rc, $buf) = piperun($cmd, "egrep -e 'SERVICE[[:space:]]+$service' | awk '{print \$5, \$7, \$8}' | grep \'ENABLED\\|NOTREADY\' | grep storage | head -n 1", "ubero");
        print "BUF: $buf\n";
        print "CRC: $crc\n";
        print "RC: $rc\n";

        if ($crc) {
            print "\t$component $component: cannot determine status\n";
            exit(1);
        } elsif ($rc || !$buf || $buf eq "") {
            print "\t$component $component is not in NOT_READY or ENABLED\n";
        } else {
            print "\t$component $component is ENABLED or NOT_READY as expected\n";
            print "SC Master: $masters{$component}\n"; 
            exit(0);
        }
  }
sleep(10);
}

print "SC Master not found...";
exit(1);
