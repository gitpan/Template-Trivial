use Test;
BEGIN { plan tests => 23; chdir 't' if -d 't' }

use blib;
use Template::Trivial;

ok(1);

my $tmpl;

##
## setup tests
##

undef $tmpl;
$tmpl = new Template::Trivial;
ok( $tmpl->strict );

undef $tmpl;
$tmpl = new Template::Trivial(strict => 0);
ok( $tmpl->strict, 0 );

$tmpl->strict(1);
ok( $tmpl->strict );

undef $tmpl;
$tmpl = new Template::Trivial;
ok( $tmpl->templates, '' );

undef $tmpl;
$tmpl = new Template::Trivial(templates => '/var/tmp/foo');
ok( $tmpl->templates, '/var/tmp/foo/' );

undef $tmpl;
$tmpl = new Template::Trivial;

## test assign_from_file (plain file)
open FOO, ">test.foo"
  or die "Could not open test.foo: $!\n";
print FOO "Foo contents\n";
close FOO;
$tmpl->assign_from_file(FOO => 'test.foo');
ok($tmpl->to_string('FOO'), "Foo contents\n");
unlink "test.foo";

## test assign_from_file (device)
$tmpl->assign_from_file(FOO => '/dev/null');
ok( $tmpl->to_string('FOO'), '' );

## test variable assignment
$tmpl->assign(FOO => 'foo');
ok( $tmpl->to_string('FOO'), 'foo' );

## test multiple variable assignment
$tmpl->assign(BAR => 'bar', BAZ => 'baz');
ok( $tmpl->to_string('BAR'), 'bar');
ok( $tmpl->to_string('BAZ'), 'baz');

## test append methods
$tmpl->assign('.FOO' => 'ster');
ok( $tmpl->to_string('FOO'), 'fooster' );
$tmpl->append(FOO => ' just');
ok( $tmpl->to_string('FOO'), 'fooster just' );

## test template definition
$tmpl->strict(0);  ## turn off stricture
$tmpl->define(bar => 'bar.tmpl');
ok($tmpl->to_string('bar'), '');

$tmpl->strict(1);  ## should warn under strict
print STDERR "A warning should appear here: ";
$tmpl->define(bar => 'bar.tmpl');
print STDERR "A warning should appear here: ";
ok($tmpl->to_string('bar'), undef );

## create bar.tmpl
open FILE, ">bar.tmpl"
  or die "Could not write bar.tmpl: $!\n";
print FILE "This is bar {BARF} so there\n";
close FILE;

## empty variable test
$tmpl->define_from_string( something => q!HI{BLANK}THERE!, blank => '' );
$tmpl->parse(BLANK => 'blank');
$tmpl->parse(SOMETHING => 'something');
ok( $tmpl->to_string('SOMETHING'), 'HITHERE' );

## FIXME: false variable test (0)

## undefined variable test
$tmpl->define(bar => 'bar.tmpl');
print STDERR "A warning should appear here: ";
$tmpl->parse(BAR => 'bar');
ok($tmpl->to_string('BAR'), "This is bar {BARF} so there\n" );

## try again
$tmpl->assign(BARF => "barfus");
$tmpl->parse(BAR => 'bar');
ok($tmpl->to_string('BAR'), "This is bar barfus so there\n");

## test parse append
$tmpl->assign(BARF => "sufrab");
$tmpl->parse('.BAR' => 'bar');
ok($tmpl->to_string('BAR'), <<_BARF_);
This is bar barfus so there
This is bar sufrab so there
_BARF_

unlink "bar.tmpl";

## complete test
my %files = ( main  => 'main.tmpl',
	      table => 'table.tmpl', );
my %content = ( main => <<_MAIN_,
<html>
<head>
{TITLE}
</head>

<body>
{TABLE}</body>
</html>
_MAIN_
		table => ,<<_TABLE_ );
<table>
{ROWS}</table>
_TABLE_

for my $file ( keys %files ) {
    open FILE, ">$files{$file}"
      or die "Could not create '$files{$file}': $!\n";
    print FILE $content{$file};
    close FILE;
}

undef $tmpl;
$tmpl = new Template::Trivial;
$tmpl->define( %files );

## do title now
$tmpl->define_from_string( title => "<title>{TITLE}</title>" );
$tmpl->assign( TITLE => "This is the title" );
$tmpl->parse( TITLE => 'title' );
ok( $tmpl->to_string('TITLE'), "<title>This is the title</title>" );

open FOO, ">title.foo"
  or die "Could not open title.foo: $!\n";
print FOO "<title>Foo: {TITLE}</title>";
close FOO;

## override
$tmpl->define( title => "title.foo" );
$tmpl->assign( TITLE => "This is the second title" );
$tmpl->parse( TITLE => 'title' );
ok( $tmpl->to_string('TITLE'), "<title>Foo: This is the second title</title>" );

## override
$tmpl->define_from_string( title => "<title>{TITLE}</title>" );
$tmpl->assign( TITLE => "This is the title" );
$tmpl->parse( TITLE => 'title' );
ok( $tmpl->to_string('TITLE'), "<title>This is the title</title>" );

## define ROWS variable
$tmpl->assign(ROWS => qq!<tr valign="top"><td>name</td><td>gecos</td></tr>\n!);
my %chars = ( fred   => "Fred Flintstone",
	      barney => "Barney Rubble",
	      wilma  => "Wilma Flintstone",
	      betty  => "Betty Rubble" );
for my $char ( sort keys %chars ) {
    $tmpl->assign('.ROWS' => qq!<tr><td>$char</td><td>$chars{$char}</td></tr>\n! );
}

$tmpl->parse( TABLE => 'table' );
$tmpl->parse( MAIN => 'main' );

ok( $tmpl->to_string('MAIN'), <<_MAIN_ );
<html>
<head>
<title>This is the title</title>
</head>

<body>
<table>
<tr valign="top"><td>name</td><td>gecos</td></tr>
<tr><td>barney</td><td>Barney Rubble</td></tr>
<tr><td>betty</td><td>Betty Rubble</td></tr>
<tr><td>fred</td><td>Fred Flintstone</td></tr>
<tr><td>wilma</td><td>Wilma Flintstone</td></tr>
</table>
</body>
</html>
_MAIN_

##
## cleanup tests
##
END {
    unlink "bar.tmpl" if -e "bar.tmpl";
    unlink "test.foo" if -e "test.foo";
    unlink "title.foo" if -e "title.foo";
    unlink values %files;
}
