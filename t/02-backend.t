use utf8;
use strict;

use Test::More 'no_plan';
use lib 't/lib';

use TreePath;


my @confs = (
              't/conf/treesync.yml',
            );

#              't/conf/treefromfile.yml',

foreach my $conf ( @confs ){

    ok( my $tp = TreePath->new(  conf  => $conf  ),
      "New TreePath ( conf => $conf)");

    is ( $tp->count, 11, 'tree has 11 nodes');
    ok( $tp->del( $tp->search({name => '♥'})), 'delete ♥');

    is ( $tp->count, 6, 'now the tree has 6 nodes');

    ok($tp->reload, 'reload tree from backend');
    is($tp->_populate_backend, 0, 'populate 0');

    is ( $tp->count, 6, 'the tree still has always 6 nodes');

    ok( my $tp2 = TreePath->new(  conf  => $conf, _populate_backend => 0  ),
        "Another TreePath with same value ( conf => $conf)");
    is ( $tp2->count, 6, 'this tree also has 6 nodes');

    unlink 't/test.db';
}
