use utf8;
use strict;

use open qw(:std :utf8);
use Test::More 'no_plan';
use lib 't/lib';

use TreePath;

# ex: t/conf/treepath.yml
#       /
#       |
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
                    name => 'G',
                    position => 1 },
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

  is_deeply( node_names($found), ['/', 'A', 'B'], "found /, A, B" );
  is_deeply( \@$not_found, ['X', 'D', 'E'], "not found X, D, E" );


  # B == found->[2] ?
  is( $B, $found->[2], 'B and found->[2] are the same');


  # test utf8 -----------------------
  ok( my $coeur = $tp->search( { name => '♥'} ), 'search ♥');
  is($coeur->{parent}->{name},'A', 'parent is A');

  # traverse ------------------------
  ok(my $coeur_nodes = $tp->traverse($coeur), 'all nodes from ♥');
  is(scalar @$coeur_nodes, 5, 'traverse ♥ and 4 children');

  my $args = {};
  ok($tp->traverse($coeur, \&myfunc, $args), 'traverse tree with function');
  is($args->{_count}, 5, '♥ as four children + himself');

  is_deeply( node_names($args->{all_nodes}), ['♥', 'G', 'E', 'I', 'J' ], "traverse and return all nodes from ♥" );

  # delete node ---------------------
  ok( my $E2 = $tp->search( { name => 'E', 'parent.name' => '♥'} ), 'search E to delete');
  #
  # before deletion
  is ( $tp->count, 11, 'before deletion tree has 11 nodes');
  is(scalar @{$coeur->{children}}, 2, 'before deletion ♥ has two children (G and E)');
  # recursively deletes E2 and children
  is($tp->del($E2), 3, 'delete E and 2 children');
  is ( $tp->count, 8, 'after deletion tree has 8 nodes');
  is(scalar @{$coeur->{children}}, 1, 'after deletion ♥ has only one child (G)');

  # add node ---------------------
  my $x = { name => 'X'};
  ok(my $X = $tp->add($coeur, $x), 'x added as a child to ♥');

  my $x_parent = $X->{parent};
  is( $x_parent->{id}, $coeur->{id}, 'X have ♥ as parent');

  my $x_parent_children = $x_parent->{children};
  is($$x_parent_children[-1]->{id}, $X->{id}, 'X is the last child of ♥');

  ok(my $G = $tp->search( { name => 'G' } ), 'search G, the first child of ♥');

  if ( defined $G->{position}) {
      # is that the sibling also has a field 'position'
      is($X->{position}, 2, 'X position is 2');

      # no position is given
      ok(my $Z = $tp->add($coeur, { name => 'Z'} ), 'z added as a child to ♥');
      is($Z->{position}, 3, 'Z position is 3');


      is_deeply( node_names($x_parent->{children}), ['G', 'X', 'Z'], "Before insert we have G, X, Z" );

      # insert_before ----------------
      ok(my $Y = $tp->insert_before($Z, { name => 'Y'} ), 'y insered before z');

      is($Z->{position}, 4, 'Z position is 4');
      is ( $tp->count, 11, 'after insertion tree has 11 nodes');

      is_deeply( node_names($x_parent->{children}), ['G', 'X', 'Y', 'Z'], "After insert we have G, X, Y, Z" );

      ok($tp->del($G),'delete G');
      is_deeply( node_names($x_parent->{children}), ['X', 'Y', 'Z'], "After delete G, we have X, Y, Z" );

      is($Z->{position}, 3, 'Z position is 3');


  }
}

sub myfunc() {
  my ($node, $args) = @_;

  $args->{all_nodes} = []
  if ( ! defined $args->{all_nodes});

  if(defined($node)) {
    push(@{$args->{all_nodes}}, $node);
    return 1;
  }
}

sub node_names {
  my $nodes = shift;
  return [map { $_->{name}} @$nodes ];
}
