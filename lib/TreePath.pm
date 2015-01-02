package TreePath;

use utf8;
use v5.10;
use Moose;
with 'MooseX::Object::Pluggable';

use Moose::Util::TypeConstraints;
use Config::JFDI;
use Carp qw/croak/;
use Data::Dumper;

our $VERSION = '0.07';

subtype MyConf => as 'HashRef';
coerce 'MyConf'
  => from 'Str' => via {
    my $conf = shift;
    my ($jfdi_h, $jfdi) = Config::JFDI->open($conf)
      or croak "Error (conf: $conf) : $!\n";
    return $jfdi->get;
  };

has conf => ( is => 'rw',
              isa => 'MyConf',
              coerce => 1,
              trigger  => sub {
                my $self = shift;
                my $args = shift;

                # if conf exist
                if ( defined $args->{$self->configword} ) {
                  croak "Error: Can not find " . $self->configword . " in your conf !"
                    if ( ! $args->{$self->configword});

                  $self->config($args->{$self->configword});

                  $self->debug($self->config->{'debug'})
                    if ( ! defined $self->debug && defined $self->config->{'debug'} );

                  $self->_search_field($self->config->{backend}->{args}->{search_field})
                      if defined $self->config->{backend}->{args}->{search_field};
                  $self->_parent_field($self->config->{backend}->{args}->{parent_field})
                      if defined $self->config->{backend}->{args}->{parent_field};

                  $self->_sync($self->config->{backend}->{args}->{sync})
                      if defined $self->config->{backend}->{args}->{sync};

                  $self->_load_backend if ! $self->can('backend');
                }
                # it's a hash
                else {
                  $self->tree($args);
                  $self->_build_tree;
                }
              }
            );



has config => (
               isa      => "HashRef",
               is       => "rw",
);

has 'configword' => (
                is       => 'rw',
                default => sub { __PACKAGE__ },
               );

has 'debug' => (
                is       => 'rw',
               );

has '_backend' => (
                is       => 'rw',
                isa      => 'Str',
               );

has '_sync' => (
                is       => 'rw',
                isa      => 'Str',
               );

has _plugin_ns => (
                is       => 'rw',
                required => 1,
                isa      => 'Str',
                default  => sub{ 'Backend' },
                  );

has _search_field => (
                is       => 'rw',
                isa      => 'Str',
                default  => sub{ 'name' },
                  );

has _parent_field => (
                is       => 'rw',
                isa      => 'Str',
                default  => sub{ 'parent' },
                  );

has _position_field => (
                is       => 'rw',
                isa      => 'Str',
                default  => sub{ 'position' },
                  );

has tree => (
                isa      => "HashRef",
                is       => "rw",
);

has root => (
                isa      => "HashRef",
                is       => "rw",
);


sub _load_backend {
  my $self = shift;
  my $backend = $self->config->{'backend'}->{name};
  $self->_backend($backend);

  $self->_log("Loading $backend backend ...");
  $self->load_plugin( $backend );
  $self->_load_tree;
  $self->_build_tree;
}

sub reload {
    my $self = shift;

    $self->_populate_backend(0)
        if $self->can('_populate_backend');

    $self->_load_tree;
}

sub _log{
  my ($self, $msg ) = @_;

  return if ! $self->debug;

  say STDERR "[debug] $msg";
}

# Load tree from backend
sub _load_tree {
  my $self = shift;

  $self->tree($self->_load);
}

# Build Tree (children, position, ...)
# parents and children become HashRef
sub _build_tree {
  my $self = shift;

  my $tree = $self->tree;
  foreach my $id ( sort keys %$tree ) {
    my $node    = $tree->{$id};
    my $parent  = $tree->{$node->{parent}};
    $node->{id} = $id;

    if ( ! $parent ){
      $self->root($node);
      next;
    }


    my $children_parent = defined $parent->{children} ? $parent->{children} : [];
    push(@$children_parent, $node );
    $parent->{children} = $children_parent;
    $node->{parent}     = $parent;
  }
}

# return the last node sorted by id
sub _last_node {
  my $self = shift;

  my @nodes_sorted_by_id = sort { $a <=> $b } map $_->{id}, values %{$self->tree};
  return $self->tree->{$nodes_sorted_by_id[-1]};
}

sub  _create {
    my $self = shift;
    my $node = shift;
    my $msg  = shift;

    return if ( ! $self->_backend || ! $self->_sync );
    $self->_log("[" . $self->_backend . "] CREATE " . $node->{name} . " | $msg");
    $self->create($node);
}

sub  _delete {
    my $self  = shift;
    my $nodes = shift;
    my $msg   = shift;

    return if ( ! $self->_backend || ! $self->_sync );
    my @nodes_name = map { $_->{$self->_search_field} } @$nodes;
    $self->_log("[" . $self->_backend . "] DELETE @nodes_name | $msg");

    $self->delete($nodes);
}

sub  _update {
    my $self = shift;
    my $node = shift;
    my $msg  = shift;

    return if ( ! $self->_backend || ! $self->_sync );
    $self->_log("[" . $self->_backend . "] UPDATE " . $node->{name} . " | $msg");
    $self->update($node);
}

sub _clone_node {
    my $self = shift;
    my $node = shift;

    my $clone = {};
    foreach my $k (keys %$node) {
        if ( $k eq 'parent'){
            $clone->{$self->_parent_field} = $node->{$k}->{id};
        }
        else {
            $clone->{$k} = $node->{$k}
        }
    }
    return $clone;
}

sub search {
  my ( $self, $args, $opts ) = @_;

  my $results = [];
  my $tree = $self->tree;
  foreach my $id  ( sort {$a <=> $b} keys %$tree ) {

    my $found=1;
    foreach my $key ( keys %$args ) {
      my $current;
      if ( $key =~ m/(.*)\.(.*)/) {
        # ex: parent.name
        if ( defined $tree->{$id}->{$1} && ref($tree->{$id}->{$1})) {
          $current = $tree->{$id}->{$1}->{$2};
        }
        else { next }
      }
      else {
        $current = $tree->{$id}->{$key};
      }
      my $value = $args->{$key};
      if ( $current ne $value ) {
        $found = 0;
        last;
      }
    }

    if ( $found ){
      if ( wantarray) {
        push(@$results, $tree->{$id});
      }
      # if found and scalar context
      else {
        return $tree->{$id};
      }
    }
  }

  return 0 if (  ! wantarray && ! $$results[0] );

  # wantarray
  return @$results;
}


# ex : search_path(/A/B/C')
sub search_path {
  my ( $self, $path, $opts ) = @_;

  # search by 'name' if not defined
  $opts->{by} = $self->_search_field if ! defined $opts->{by};

  croak "path must be start by '/' !: $!\n" if ( $path !~ m|^/| );

  my $nodes = [ split m%/%, $path ];
  $$nodes[0] = '/';

  my (@found, @not_found);
  my $parent = '/';
  foreach my $node ( @$nodes ) {
    my $args = { $opts->{by} => $node, "parent\.$opts->{by}" => $parent};
    my $result = $self->search($args, $opts);

    $parent = $result->{$opts->{by}} if $result;

    if ( $result ) {
      push(@found, $result);
    }
    else {

      push(@not_found, $node);
    }
  }

  if ( wantarray ) {
    return ( \@found, \@not_found );
  }
  else {
    if ( $not_found[-1] ) {
      return '';
    }
    else {
      return $found[-1];
    }
  }
}


sub count {
  my $self = shift;

  return scalar keys %{$self->tree};
}

sub dump {
  my $self = shift;
  my $var  = shift;

  $var = $self->tree if ! defined $var;
  $Data::Dumper::Maxdepth = 3;
  $Data::Dumper::Sortkeys = 1;
  $Data::Dumper::Terse = 1;
  return Dumper($var);
}

sub traverse {
  my ($self, $node, $funcref, $args) = @_;

  return 0 if ( ! $node );
  $args ||= {};
  $args->{_count} = 1 if ! defined ($args->{_count});

  my $nofunc = 0;
  if ( ! $funcref ) {
    $nofunc=1;
    $funcref = sub {    my ($node, $args) = @_;
                        $args->{_each_nodes} = []
                          if ( ! defined $args->{_each_nodes});
                        if(defined($node)) {
                          push(@{$args->{_each_nodes}}, $node);
                          return 1;
                        }
                      }
  }
  # if first node
  if ( $args->{_count} == 1 ) {
    return 0 if ( ! &$funcref( $node, $args ) )
  }

  if(defined($node->{children})) {

    foreach my $child ( @{$node->{children}} ) {
      return 0 if ( ! &$funcref( $child, $args ) );
      $args->{_count}++;
      $self->traverse( $child, $funcref, $args );
    }
  }

  return $args->{_each_nodes} if $nofunc;
  return 1;
}


sub del {
  my ($self, @nodes) = @_;

  my @deleted;
  foreach my $node ( @nodes ) {

      my $father = $node->{parent};

      # removes the child's father
      my $id = 0;
      my $is_finded = 0;
      foreach my $child ( @{$father->{children}}) {
          # decrease position
          if ( $is_finded) {
              $child->{$self->_position_field}--;
              $self->_update($child, 'change position');
          }

          if ( $child->{$self->_search_field} eq $node->{$self->_search_field} &&
                   $child->{parent} eq $node->{parent} ){
              splice ( @{$father->{children}},$id,1);
              $is_finded = 1;
          }
          $id++;
      }

      # traverse child branches and delete it
      my $nodes = $self->traverse($node);
      push(@deleted,map { delete $self->tree->{$_->{id}} } @$nodes);
      $self->_delete($nodes, "delete " . @$nodes . " node(s)");
  }
  return @deleted;
}

# Inserts a node beneath the parent at the given position.
sub add {
  my ($self, $parent, $node, $position) = @_;

  $node->{parent} = $parent;
  my $next_id = $self->_last_node->{id};
  $next_id++;
  $node->{id} = $next_id;

  # add node as last children
  if ( ! $position ) {
      # if last child's parent have a 'position' field
      if ( defined $parent->{children} ) {

          if ( defined ${$parent->{children}}[-1] && defined ${$parent->{children}}[-1]->{$self->_position_field} ) {

              my $next_position = ${$parent->{children}}[-1]->{$self->_position_field};
              $next_position++;
              $node->{$self->_position_field} = $next_position;
          }
      }
      else {
          $parent->{children} = [];
      }

      # add child's parent
      push(@{$parent->{children}}, $node);

  }
  # use the position
  else {

      my $is_finded = 0;
      foreach my $child ( @{$parent->{children}} ) {

          if ( $child->{$self->_position_field} >= $position) {
              $is_finded = 1;
              $node->{$self->_position_field} = $position;
          }
          $child->{$self->_position_field}++
              if ( $is_finded);
      }
      splice @{$parent->{children}}, $position-1, 0, $node;
  }

  # add node in tree
  $self->_create($node, 'add node ' . $node->{$self->_search_field});
  $self->tree->{$next_id} = $node;
}

sub insert_before {
  my ($self, $sibling, $node) = @_;

  my $position;

  if ( ! defined $sibling->{$self->_position_field}) {
      return $self->add($sibling->{parent}, $node, 1 );
  }

  return $self->add($sibling->{parent}, $node, $sibling->{$self->_position_field} );
}


=head1 NAME

TreePath - Simple Tree Path!

=head1 VERSION


=head1 SYNOPSIS

 use TreePath;

 my $tp = TreePath->new(  conf  => $conf  );
 my $tree = $tp->tree;

 # All nodes are hash
 # The first is called 'root'
 my $root = $tp->root;

 # a node can have children
 my $children = $root->{children};

=head1 SUBROUTINES/METHODS

=head2 new($method => $value)

 # for now there are two backend : DBIX and File
 $tp = TreePath->new( conf => 't/conf/treefromdbix.yml')

 # see t/conf/treepath.yml for hash structure
 $tp = TreePath->new( datas => $datas);

 also see t/01-tpath.t

=cut

=head2 tree

 $tree = $tp->tree;

=cut

=head2 reload

 # reload tree from backend
 $tree = $tp->reload;

=cut

=head2 nodes

 $root = $tp->root;
 # $root and $tree->{1} are the same node

 This is the root node ( a simple hashref )
 it has no parent.
     {
       '1' => {
                'id' => '1',
                'name' => '/',
                'parent' => '0'
              }
     }

  $A = $tp->search( { name => 'A' } );
  See the dump :

    {
      'children' => [
                      {
                        'children' => 'ARRAY(0x293ce00)',
                        'id' => '3',
                        'name' => 'B',
                        'parent' => $VAR1
                      },
                      {
                        'children' => 'ARRAY(0x2fd69b0)',
                        'id' => '7',
                        'name' => 'F',
                        'parent' => $VAR1
                      }
                    ],
      'id' => '2',
      'name' => 'A',
      'parent' => {
                    'children' => [
                                    $VAR1
                                  ],
                    'id' => '1',
                    'name' => '/',
                    'parent' => '0'
                  }
    }

    => 'parent' is a reference on root node and 'children' is an array containing 2 nodes

=cut

=head2 search (hashref)

 # in scalar context return the first result
 my $E = $tp->search( { name => 'E' } );

 # return all result in array context
 my @allE = $tp->search( { name => 'E' } );

 # It is also possible to specify a particular field of a hash
 my $B = $tp->search( { name => 'B', 'parent.name' => 'A'} );

=cut

=head2 search_path (PATH)

 # Search a path in a tree
 # in scalar context return last node
 my $c = $tp->search_path('/A/B/C');

 # in array context return found and not_found nodes
 my ($found, $not_found) = $tp->search_path('/A/B/X/D/E');

=cut

=head2 dump

 # dump whole tree
 print $tp->dump;

 # dump a node
 print $tp->dump($c);;

=cut

=head2 count

 # return the number of nodes
 print $tp->count;

=cut

=head2 traverse ($node, [\&function], [$args])

 # return an arrayref of nodes
 my $nodes = $tp->traverse($node);

 # or use a function on each nodes
 $tp->traverse($node, \&function, $args);

=cut

=head2 del ($node)

 # delete recursively all children and node
 $deleted = $tp->del($node);

 # delete several nodes at once
 @del = $tp->del($n1, $n2, ...);

=cut

=head2 add ($parent, $node)

 # add a node beneath the parent at the last position.
 $Z = $tp->add($parent, { name => 'Z' });

 # or at given position
 $Z = $tp->add($parent, { name => 'Z', position => 2 });

=cut


=head2 insert_before ($sibling, $node)

 # Inserts a node beneath the parent before the given sibling.
 $Y = $tp->insert_before($Z, { name => 'Y' });

=cut



=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-tpath at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TreePath>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TreePath


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=TreePath>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/TreePath>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/TreePath>

=item * Search CPAN

L<http://search.cpan.org/dist/TreePath/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Daniel Brosseau.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of TreePath
