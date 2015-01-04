use utf8;
package Schema::TPath::Result::PageWithPosition;

=head1 NAME

Schema::TPath::Result::Page

=cut

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';


__PACKAGE__->load_components;

=head1 TABLE: C<pages>

=cut

__PACKAGE__->table("pageswithposition");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  is_nullable: 0

=head2 parent

  data_type: 'integer'
  is_nullable: 0
  default_value: 0

=head2 position

  data_type: 'integer'
  is_nullable: 1
  default_value: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_nullable => 0 },
  "name",
  { data_type => "varchar", is_nullable => 1, size => undef },
  "parent_id",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "position",
  { data_type => "integer", is_nullable => 1 },
);


=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<name_parent_unique>

=cut

__PACKAGE__->add_unique_constraint("name_parent_unique", ["name", "parent_id"]);



__PACKAGE__->meta->make_immutable;

1;
