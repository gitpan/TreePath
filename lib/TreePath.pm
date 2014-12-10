package TreePath;

use v5.10;
use Moose;
with 'MooseX::Object::Pluggable';

use Moose::Util::TypeConstraints;
use Config::JFDI;
use Carp qw/croak/;
use Data::Dumper;

our $VERSION = '0.02';

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

                croak "Error: Can not find " . $self->configword . " in your conf !"
                  if ( ! $args->{$self->configword});

                $self->config($args->{$self->configword});

                $self->debug($self->config->{'debug'}) if ( defined $self->config->{'debug'} );

                $self->_load_backend if ! $self->can('backend');
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

has _plugin_ns => (
                is       => 'rw',
                required => 1,
                isa      => 'Str',
                default  => sub{ 'Backend' },
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

  $self->_log("Loading $backend backend ...");
  $self->load_plugin( $backend );
  $self->_load_tree;
  $self->_build_tree;
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

  # search by 'name' if not defined
  $opts->{by} ='name' if ! defined $opts->{by};

  croak "path must be start by '/' !: $!\n" if ( $path !~ m|^/| );

  my $nodes = [ split m%/%, $path ];
  $$nodes[0] = '/';

  my $lasted_obj;
  my (@found, @not_found);
  my $parent = '/';
  foreach my $node ( @$nodes ) {
    my $args = { $opts->{by} => $node, 'parent.name' => $parent};
    my $result = $self->search($args, $opts);

    $parent = $result->{name} if $result;

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


sub dump {
  my $self = shift;
  my $var  = shift;

  $var = $self->tree if ! defined $var;
  $Data::Dumper::Maxdepth = 3;
  $Data::Dumper::Sortkeys = 1;
  $Data::Dumper::Terse = 1;
  return Dumper($var);
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

=head2 search

  # search by hashref

  # in scalar context return the first result
  my $E = $tp->search( { name => 'E' } );

  # return all result in array context
  my @allE = $tp->search( { name => 'E' } );

  # It is also possible to specify a particular field of a hash
  my $B = $tp->search( { name => 'B', 'parent.name' => 'A'} );

=cut

=head2 search_path

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
