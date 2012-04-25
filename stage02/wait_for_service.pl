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

run_command("ssh -o StrictHostKeyChecking=no root\@$masters{CLC} 'cd /root; if ( test -f /root/admin_cred.zip ); then unzip -o /root/admin_cred.zip; fi'");

for($i=0; $i <=24 ; $i++) {
describe_services();
find_real_master($component);
    print "MASTER: $masters{$component}\n";
    if($masters{$component}) {
        open(FH, ">/tmp/ec2ops.out.$$");
        print FH "$current_artifacts{master_ds_buf}\n";
        close(FH);
        $cmd = "cat /tmp/ec2ops.out.$$";
        ($crc, $rc, $buf) = piperun($cmd, "egrep -e 'SERVICE[[:space:]]+$service' | awk '{print \$5, \$7, \$8}' | grep ENABLED | grep storage | head -n 1", "ubero");
        print "BUF: $buf\n";
        if ($crc) {
            print "\t$component $component: cannot determine status\n";
            exit(1);
        } elsif ($rc || !$buf || $buf eq "") {
            print "\t$component $component is NOT ENABLED\n";
        } else {
            print "\t$component $component is ENABLED\n";
            print "SC Master: $masters{$component}\n"; 
            exit(0);
        }
    }
sleep(10);
}

print "SC Master not found...";
exit(1);
