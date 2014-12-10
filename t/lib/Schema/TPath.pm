use utf8;
package Schema::TPath;

use Moose;
use MooseX::MarkAsMethods autoclean => 1;

extends 'DBIx::Class::Schema';

our $VERSION = 1;

__PACKAGE__->load_namespaces;

sub _populate {
  my $self = shift;

  my @pages = $self->populate(
        'Page',
        [
            [ qw/ id name parent_id / ],
            [     1,  '/', 0        ],
            [     2,  'A', 1        ],
            [     3,  'B', 2        ],
            [     4,  'C', 3        ],
            [     5,  'D', 4        ],
            [     6,  'E', 4        ],
            [     7,  'F', 2        ],
            [     8,  'G', 7        ],
            [     9,  'E', 7        ],
            [     10, 'I', 9        ],
            [     11, 'J', 9        ],
        ]
    );

}
__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;
