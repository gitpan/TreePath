use utf8;
use strict;
use Test::More 'no_plan';
use lib 't/lib';

use TreePath;

# ex: t/conf/treepath.yml
#
#       A
#      / \
#     B   ♥
#    /   / \
#   C   G   E
#  / \     / \
# D   E   I   J
#
my $simpletree = {
             '1' => {
                     parent => '0',
                     name => '/'},
             '2'=> {
                    parent => '1',
                    name => 'A'},
             '3'=> {
                    parent => '2',
                    name => 'B'},
             '4'=> {
                    parent => '3',
                    name => 'C'},
             '5'=> {
                    parent => '4',
                    name => 'D'},
             '6'=> {
                    parent => '4',
                    name => 'E'},
             '7'=> {
                    parent => '2',
                    name => '♥'},
             '8'=> {
                    parent => '7',
                    name => 'G'},
             '9'=> {
                    parent => '7',
                    name => 'E'},
             '10'=> {
                     parent => '9',
                     name => 'I'},
             '11'=> {
                     parent => '9',
                     name => 'J'}
            };




my @confs = ( $simpletree,
              't/conf/treefromfile.yml',
              't/conf/treefromdbix.yml',
            );

foreach my $conf ( @confs ){

  ok( my $tp = TreePath->new(  conf  => $conf  ),
      "New TreePath ( conf => $conf)");

  my $tree = $tp->tree;
  isa_ok($tree, 'HASH');

  my $root = $tp->root;
  is($root,$tree->{1}, 'retrieve root');
  isa_ok($root, 'HASH', "root" );

  # search --------------------------
  # in scalar context, return the first found
  ok( my $E = $tp->search( { name => 'E' } ), 'first E found');


  isa_ok($E, 'HASH');
  isa_ok($E->{parent},      'HASH' , 'parent');
  is($E->{parent}->{name}, 'C', 'C is parent of E');

  # If not found, retounr undef
  ok( ! $tp->search( { name => 'Z' } ), 'Z not found');

  # in array context, returns all found
  ok(my @allE = $tp->search( { name => 'E' } ), 'search all E');
  is(@allE, 2, 'both found E');


  # It is also possible to specify a particular field of a hash
  ok( my $B = $tp->search( { name => 'B', 'parent.name' => 'A'} ), 'search B, specify parent.name to search in hashref');
  is($B->{parent}->{name}, 'A', 'A is parent of B');


  # search_path ---------------------
  # in scalar context, return the last
  ok(my $slash    = $tp->search_path('/'), 'search / in scalar context, return / ');
  isa_ok($slash, 'HASH');
  is($slash->{name},'/', 'name is /');
  is ($slash, $root, 'slash and root are the same');


  ok(my $c    = $tp->search_path('/A/B/C'), 'search /A/B/C in scalar context, return C ');
  is($c->{name},'C', 'name is C');

  ok(my $childrenc = $c->{children}, 'children c');
  is($childrenc->[0]->{name}, 'D', 'first child is D');
  is($childrenc->[1]->{name}, 'E', 'second child is E');

  my $notfound = $tp->search_path('/A/B/Z');
  is ($notfound,'', "search /A/B/Z in scalar context, return '' (not found)" );

  # in array context, return found and not_found
  # found = /, A, B and not_found = X, D, E
  ok(my ($found, $not_found) = $tp->search_path('/A/B/X/D/E'), 'search /A/B/X/D/E in array context');

  my @found_names = map { $_->{name} } @$found;
  is_deeply( \@found_names, ['/', 'A', 'B'], "found /, A, B" );
  is_deeply( \@$not_found, ['X', 'D', 'E'], "not found X, D, E" );


  # B == found->[2] ?
  is( $B, $found->[2], 'B and found->[2] are the same');

  # test utf8
  ok( my $coeur = $tp->search( { name => '♥'} ), 'search ♥');
  is($coeur->{parent}->{name},'A', 'parent is A');

}
