
#########################

use Test::More tests => 26;
use Test::Deep;
BEGIN { use_ok('Cache::FastMmap') };
use Data::Dumper;
use strict;

#########################

# Test maintaining expire_on through get_and_set

# Test a backing store just made of a local hash
my %BackingStore = ();

my $FC = Cache::FastMmap->new(
  serializer => '',
  init_file => 1,
  num_pages => 1,
  page_size => 8192,
  context => \%BackingStore,
  write_cb => sub { $_[0]->{$_[1]} = $_[2]; },
  write_action => 'write_back',
  expire_time => 3,
);

ok( defined $FC );

ok( $FC->set('foo', '123abc', 2), 'store item 1');
ok( $FC->set('bar', '456def', 3), 'store item 2');
ok( $FC->set('baz', '789ghi'),    'store item 3');
is( $FC->get('foo'), '123abc',  "get item 1");
is( $FC->get('bar'), '456def',  "get item 2");
is( $FC->get('baz'), '789ghi',  "get item 3");

sleep 1;

sub cb { return ($_[1].'a', { expire_on => $_[2]->{expire_on} }); };
sub cb2 { return ($_[1].'a'); };
is( $FC->get_and_set('foo', \&cb), '123abca',  "get_and_set item 1 after sleep 1");
is( $FC->get_and_set('bar', \&cb), '456defa',  "get_and_set item 2 after sleep 1");
is( $FC->get_and_set('baz', \&cb2), '789ghia', "get_and_set item 3 after sleep 1");

my $now = time;
my @e = $FC->get_keys(2);
cmp_deeply(
  \@e,
  bag(
    superhashof({ key => 'foo', value => '123abca', last_access => num($now, 1), expire_on => num($now+1, 1) }),
    superhashof({ key => 'bar', value => '456defa', last_access => num($now, 1), expire_on => num($now+2, 1) }),
    superhashof({ key => 'baz', value => '789ghia', last_access => num($now, 1), expire_on => num($now+3, 1) }),
  ),
  "got expected keys"
) || diag explain $now, \@e;

sleep 1;

is( $FC->get('foo'), undef,      "get item 1 after sleep 2");
is( $FC->get('bar'), '456defa',  "get item 2 after sleep 2");
is( $FC->get('baz'), '789ghia',  "get item 3 after sleep 2");

is( $FC->get_and_set('bar', \&cb), '456defaa',  "get_and_set item 2 after sleep 2");

$now = time;
@e = $FC->get_keys(2);
cmp_deeply(
  \@e,
  bag(
    superhashof({ key => 'bar', value => '456defaa', last_access => num($now, 1), expire_on => num($now+1, 1) }),
    superhashof({ key => 'baz', value => '789ghia',  last_access => num($now, 1), expire_on => num($now+2, 1) }),
  ),
  "got expected keys"
) || diag explain $now, \@e;

sleep 1;

is( $FC->get('foo'), undef,      "get item 1 after sleep 3");
is( $FC->get('bar'), undef,      "get item 2 after sleep 3");
is( $FC->get('baz'), '789ghia',  "get item 3 after sleep 3");

@e = $FC->get_keys(2);
cmp_deeply(
  \@e,
  bag(
    superhashof({ key => 'baz', value => '789ghia',  last_access => num($now, 1), expire_on => num($now+1, 1) }),
  ),
  "got expected keys"
) || diag explain $now, \@e;

sleep 1;

is( $FC->get('foo'), undef,      "get item 1 after sleep 4");
is( $FC->get('bar'), undef,      "get item 2 after sleep 4");
is( $FC->get('baz'), undef,      "get item 3 after sleep 4");

@e = $FC->get_keys(2);
cmp_deeply(
  \@e,
  bag(),
  "got expected keys (empty)"
) || diag explain $now, \@e;

$FC->empty(1);

ok( eq_hash(\%BackingStore, { foo => '123abca', bar => '456defaa', baz => '789ghia' }), "items match expire 2");


