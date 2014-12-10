package TreePath::Backend::DBIx;
$TreePath::Backend::DBIx::VERSION = '0.02';
use Moose::Role;
use base 'DBIx::Class::Schema';
use Carp qw/croak/;
use Path::Class;
use Hash::Merge;

use FindBin '$Bin';
require UNIVERSAL::require;


my $attrs = {
             # starting with v3.3, SQLite supports the "IF EXISTS" clause to "DROP TABLE",
             # even though SQL::Translator::Producer::SQLite 1.59 isn't passed along this option
             # see https://rt.cpan.org/Ticket/Display.html?id=48688
             sqlite_version => 3.3,
             add_drop_table => 0,
             no_comments => 0,
             RaiseError => 1,
             PrintError => 0,
            };

has dsn          => (
                     is        => 'rw',
                     default   => sub {
                       my $self = shift;
                       return $self->model_config->{'connect_info'}->{dsn};
                     }
                    );

has model_config => (
                     is         => 'rw',
                     lazy_build => 1,
                    );

has 'schema'     => (
                     is        => 'rw',
                     predicate => 'has_schema',
#                     lazy_build      => 1,
                    );


sub _build_model_config {
  my $self = shift;
  my $config       = $self->conf;

  my $model_config = $config->{$self->config->{backend}->{args}->{model}}
    or croak "'backend/args/model' is not defined in conf file !";
  return $model_config
}

sub _connect_info {
  my $self = shift;

  my $model_config = $self->model_config;

  my ($dsn, $user, $password, $unicode_option, $db_type);
  eval {
    if (!$dsn)
      {
        if (ref $model_config->{'connect_info'}) {

          $dsn      = $model_config->{'connect_info'}->{dsn};
          $user     = $model_config->{'connect_info'}->{user};
          $password = $model_config->{'connect_info'}->{password};

          # Determine database type amongst: SQLite, Pg or MySQL
          $dsn =~ m/^dbi:(\w+)/;
          $db_type = lc($1);
          my %unicode_connection_for_db = (
                'sqlite' => { sqlite_unicode    => 1 },
                'pg'     => { pg_enable_utf8    => 1 },
                'mysql'  => { mysql_enable_utf8 => 1 },

                );
          $unicode_option = $unicode_connection_for_db{$db_type};
        }
        else {
          $dsn = $model_config->{'connect_info'};
        }
      }
  };

  if ($@) {
    die "Your DSN line in " . $self->conf . " doesn't look like a valid DSN.";
  }
  die "No valid Data Source Name (DSN).\n" if !$dsn;
  $dsn =~ s/__HOME__/$FindBin::Bin\/\.\./g;

  if ( $db_type eq 'sqlite' ){
    $dsn =~ m/.*:(.*)$/;
    my $dir = dir($1)->parent;
    $dir->mkpath;
  }

  my $merge    = Hash::Merge->new( 'LEFT_PRECEDENT' );
  my $allattrs = $merge->merge( $unicode_option, $attrs );

  return $dsn, $user, $password, $allattrs;
}


sub _load {
  my $self = shift;

  $self->_log("Loading tree from dbix");

  my($dsn, $user, $password, $allattrs) = $self->_connect_info;

  my $schema_class =  $self->model_config->{schema_class};
  my $schema = $schema_class->connect($dsn,$user,$password,$allattrs);

  my $source_name = $self->config->{backend}->{args}->{source_name};
  eval { $schema->resultset($source_name)->count };

  if ( $@ ) {
    print "Deploy and populate $dsn\n" if $self->debug;
    $schema->deploy;
    $schema->_populate;
  }
  $self->schema($schema);

  my @pages = $self->schema->resultset($source_name)->search();
  return { map { $_->id => { name => $_->name, parent => $_->parent_id } } @pages};
}

=head1 NAME

TreePath::Backend::DBIx - Backend 'DBIx' for TreePath

=head1 VERSION

version 0.02

=head1 CONFIGURATION

See t/conf/treefromdb.yml

         Model::TPath:
           schema_class: Schema::TPath
           connect_info:
             dsn: 'dbi:SQLite:dbname=:memory:'

         TreePath:
           debug: 0
           backend:
             name: DBIx
             model: Model::TPath


=head2 REQUIRED SCHEMA

See t/lib/Schema/TPath/Result/

=head1 AUTHOR

Daniel Brosseau, C<< <dab at catapulse.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Daniel Brosseau.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
