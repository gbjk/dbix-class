use strict;
use warnings;  

use Test::More;
use lib qw(t/lib);
use DBICTest;

plan tests => 6;

# Set up the "usual" sqlite for DBICTest
my $schema = DBICTest->init_schema;

# This is how we're generating exceptions in the rest of these tests,
#  which might need updating at some future time to be some other
#  exception-generating statement:

sub throwex { $schema->resultset("Artist")->search(1,1,1); }
my $ex_regex = qr/Odd number of arguments to search/;

# Basic check, normal exception
eval { throwex };
like($@, $ex_regex);

# Now lets rethrow via exception_action
$schema->exception_action(sub { die @_ });
eval { throwex };
like($@, $ex_regex);

# Now lets suppress the error
$schema->exception_action(sub { 1 });
eval { throwex };
ok(!$@, "Suppress exception");

# Now lets fall through and let croak take back over
$schema->exception_action(sub { return });
eval { throwex };
like($@, $ex_regex);

# Whacky useless exception class
{
    package DBICTest::Exception;
    use overload '""' => \&stringify, fallback => 1;
    sub new {
        my $class = shift;
        bless { msg => shift }, $class;
    }
    sub throw {
        my $self = shift;
        die $self if ref $self eq __PACKAGE__;
        die $self->new(shift);
    }
    sub stringify {
        "DBICTest::Exception is handling this: " . shift->{msg};
    }
}

# Try the exception class
$schema->exception_action(sub { DBICTest::Exception->throw(@_) });
eval { throwex };
like($@, qr/DBICTest::Exception is handling this: $ex_regex/);

# While we're at it, lets throw a custom exception through Storage::DBI
eval { DBICTest->schema->storage->throw_exception('floob') };
like($@, qr/DBICTest::Exception is handling this: floob/);
