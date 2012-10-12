#!/usr/bin/perl

require "ec2ops.pl";

my $component = "SC00";
my $service = "storage";

parse_input();
print "SUCCESS: parsed input\n";

setlibsleep(0);
print "SUCCESS: set sleep time for each lib call\n";

describe_services();
find_real_master("CLC");


if( $source_lst[0] eq "PACKAGE" || $source_lst[0] eq "REPO" ){                                                                                                     
  $ENV{'EUCALYPTUS'} = "";
} else {
  $ENV{'EUCALYPTUS'} = "/opt/eucalyptus";
} 

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
