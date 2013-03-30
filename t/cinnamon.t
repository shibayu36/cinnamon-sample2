use strict;
use warnings;

use base qw(Test::Class);

use Test::More;
use Path::Class;

my $root = file(__FILE__)->dir->parent;

sub update : Tests {
    qx{ cinnamon --config $root/config/deploy.pl production clean };

    my $out = qx{ cinnamon --config $root/config/deploy.pl production update };
    like $out, qr{\[success\]: cinnamon-web1, cinnamon-web2};

    $out = qx{ cinnamon --config $root/config/deploy.pl production directory };
    like $out, qr{cinnamon-web1 release count : 1};
    like $out, qr{cinnamon-web2 release count : 1};

    $out = qx{ cinnamon --config $root/config/deploy.pl production update };
    like $out, qr{\[success\]: cinnamon-web1, cinnamon-web2};

    $out = qx{ cinnamon --config $root/config/deploy.pl production directory };
    like $out, qr{cinnamon-web1 release count : 2};
    like $out, qr{cinnamon-web2 release count : 2};
}

__PACKAGE__->runtests;

1;
