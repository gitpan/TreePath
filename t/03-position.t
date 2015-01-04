use utf8;
use strict;

use Test::More 'no_plan';
use lib 't/lib';

use TreePath;


my @confs = (
              't/conf/treewithposition.yml',
            );


foreach my $conf ( @confs ){

    ok( my $tp = TreePath->new(  conf  => $conf, debug => 0  ),
      "New TreePath ( conf => $conf)");

    ok($tp->add(0, { name => '/'}), 'add root');

    my $root = $tp->root;
    is($root,$tp->tree->{1}, 'retrieve root');
    isa_ok($root, 'HASH', "root" );

    ok(my $A = $tp->add($root, {name => 'A'}), 'add A');
    is(defined $A->{position}, '', 'A position is not defined');

    ok(my $C = $tp->add($root, {name => 'C'}), 'add C');
    is(defined $C->{position}, '', 'C position is not defined');

    # Add a node with a position
    ok(my $B = $tp->add($root, {name => 'B'}, 2), 'add B at second position');

    # now all nodes have a position
    is($A->{position}, 1,'position A : 1');
    is($B->{position}, 2,'position B : 2');
    is($C->{position}, 3,'position C : 3');

    ok(my $D = $tp->insert_before($B, { name => 'D'}), 'insert D before B');
    is($B->{position}, 3,'now position B : 3');
    is($D->{position}, 2,'position D : 2');

}
unlink 't/test.db';
