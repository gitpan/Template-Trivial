package Template::Trivial;
use strict;
use 5.00503;

use vars qw($VERSION);
$VERSION = '0.06';

use vars qw($STRICT);           ## template stricture
use vars qw($TMPL_DIR);         ## template directory
use vars qw(%VARIABLES);        ## template variables (e.g., FOO, BAR)
use vars qw(%TEMPLATE_NAME);    ## template aliases (e.g., foo, bar)
use vars qw(%TEMPLATE_CACHE);   ## template contents

my $VAR_RE  = qr(^[A-Z][A-Z0-9_-]*?$)o;
my $TMPL_RE = qr(^[a-z][a-z0-9_-]*?$)o;
my $TVAR_RE = qr!\{([A-Z][A-Z0-9_-]*?)\}!o;

sub new {
    my $class = shift;
    my $proto = ref($class) || $class;
    my $self  = { };
    my %parms = @_;

    bless $self, $proto;

    $STRICT = ( defined $parms{strict} 
		? $parms{strict} 
		: 1 );
    $TMPL_DIR = ( defined $parms{templates} 
		  ? $parms{templates}
		  : '' );
    %VARIABLES      = ();
    %TEMPLATE_NAME  = ();
    %TEMPLATE_CACHE = ();

    return $self;
}

sub strict {
    my $self = shift;
    $STRICT = ( @_ ? shift : $STRICT );
}

sub templates {
    my $self = shift;

    if( @_ ) {  ## new assignment
	$TMPL_DIR = shift;
	if( $TMPL_DIR && $TMPL_DIR !~ m!/$! ) {
	    $TMPL_DIR .= '/';
	}
    }

    return $TMPL_DIR;
}

sub define {
    my $self    = shift;
    my %defines = @_;

    for my $tmpl ( keys %defines ) {
	my $path = ( $defines{$tmpl} =~ m!^/!o
		     ? $defines{$tmpl}
		     : $TMPL_DIR . $defines{$tmpl} );

	if( $STRICT ) {
	    warn "Illegal template alias name '$tmpl'\n"
	      unless $tmpl =~ $TMPL_RE;

	    unless( -f $path || -c _ ) {
		warn "File '$path' ($tmpl) is not a file\n";
		next;
	    }
	}

	$TEMPLATE_NAME{$tmpl} = $path;

	## redefining a template clears it from the cache
	delete $TEMPLATE_CACHE{$tmpl}
	  if exists $TEMPLATE_CACHE{$tmpl};
    }
}

## FIXME: add an alias or two for define_from_string method

sub define_from_string {
    my $self = shift;
    my %defines = @_;

    for my $tmpl ( keys %defines ) {
	$TEMPLATE_CACHE{$tmpl} = $defines{$tmpl};
    }
}

sub assign {
    my $self = shift;
    my %assign = @_;

    for my $var ( keys %assign ) {
	my $append = $var =~ s/^\.//o;

	if( $STRICT ) {
	    warn "Illegal variable name '$var'\n"
	      unless $var =~ $VAR_RE;
	}

	if( $append ) {
	    $VARIABLES{$var} .= $assign{".$var"};
	}
	else {
	    $VARIABLES{$var} = $assign{$var};
	}
    }
}

sub assign_from_file {
    my $self = shift;
    my %assign = @_;

    for my $var ( keys %assign ) {
	my $append = $var =~ s/^\.//o;

	my $path = ( $assign{$var} =~ m!^/!
		     ? $assign{$var}
		     : $TMPL_DIR . $assign{$var} );

	if( $STRICT ) {
	    warn "Illegal variable name '$var'\n"
	      unless $var =~ $VAR_RE;

	    unless( -f $path || -c _ ) {
		warn "File '$path' is not a file\n";
		next;
	    }
	}

	open FILE, "$path"
	  or do {
	      warn "Could not open '$path': $!\n";
	      next;
	  };
	local($/) = undef;
	if( $append ) {
	    $VARIABLES{$var} .= <FILE>;
	}
	else {
	    $VARIABLES{$var} = <FILE>;
	}
	close FILE;
    }
}

sub append {
    my $self   = shift;
    my %assign = @_;

    for my $var ( keys %assign ) {
	if( $STRICT ) {
	    warn "Illegal key name '$var'\n"
	      unless $var =~ $VAR_RE;
	}

	$VARIABLES{$var} .= $assign{$var};
    }
}

## FIXME: append_from_file?
## FIXME: any defaults for to_string('MAIN'), etc.? How about
## FIXME: parse('MAIN') implies parse('MAIN => 'main')?

sub parse {
    my $self  = shift;
    my %parse = @_;

    while( my($var, $tmpl) = each %parse ) {
	my $append  = $var =~ s/^\.//o;
	my $file;

	## find the template in our cache
	unless( defined $TEMPLATE_CACHE{$tmpl} ) {
	    open TMPL, "$TEMPLATE_NAME{$tmpl}"
	      or do {
		  warn "Could not open template ($tmpl) '$TEMPLATE_NAME{$tmpl}': $!\n";
		  next;
	      };
	    local($/) = undef;
	    $TEMPLATE_CACHE{$tmpl} = <TMPL>;
	    close TMPL;
	}

	$file = $TEMPLATE_CACHE{$tmpl};

	## parse the template
	$file =~ s{$TVAR_RE}{
	    if( exists $VARIABLES{$+} ) {
		$VARIABLES{$+};
	    }
	    else {
		if( $STRICT ) {
		    warn "Unknown variable '$+' found.\n";
		}
		"{$+}";  ## put it back how it was
	    }
	}xge;

	if( $append ) {
	    $VARIABLES{$var} .= $file;
	}
	else {
	    $VARIABLES{$var} = $file;
	}
    }
}

sub to_string {
    my $self = shift;

    if( $STRICT ) {
	unless( $_[0] && exists $VARIABLES{$_[0]} && $_[0] =~ $VAR_RE ) {
	    warn "Undefined or unknown variable '$_[0]' found.\n";
	    return undef;
	}
    }

    return ( defined $VARIABLES{$_[0]} ? $VARIABLES{$_[0]}: '' );
}

## FIXME: clear methods?

1;
__END__

=head1 NAME

Template::Trivial - Simple Substitution Templates

=head1 SYNOPSIS

  use Template::Trivial;

  my $tmpl = new Template::Trivial( templates => '/path/to/templates' );
  $tmpl->define( main => 'main.tmpl',
                 list => 'list.tmpl' );
  $tmpl->define_from_string( item => '<li>{ITEM}' );

  for $i ( 1 .. 3 ) {
      $tmpl->assign( ITEM    => "Thingy $_" );
      $tmpl->parse( '.ITEMS' => 'item' );
  }

  $tmpl->parse(LIST => 'list' );
  $tmpl->parse(MAIN => 'main' );

  ## print out
  print $tmpl->to_string('MAIN');

=head1 DESCRIPTION

Template::Trivial is heavily inspired by the excellent and stable
CGI::FastTemplate written by Jason Moore. We introduce a slightly
modified syntax, fewer features, and a slight execution improvment
over CGI::FastTemplate.

=head2 Philosophy

The design goals of Template::Trivial were:

=over 4

=item *

quick execution; Template::Trivial runs about 10% faster than
CGI::FastTemplate, which is still one of the fastest templating
modules on CPAN.

=item *

complete separation of code and data: your web designer doesn't need
to learn any special syntax other than the template variables ({FOO},
{BLECH}). Web designers can use their favorite editors to write their
documents and you (the programmer) supply the logic and populate the
variables in your code. A surprising amount of complexity can be
achieved very simply using this technique, including loops, if-then
constructs, etc.

Many sites using CGI::FastTemplate already know this, but it is common
for the programmer to set a variety of variables and then select
different templates based on some business rules or other constraints.

=item *

lightweight design: Template::Trivial is a pure-Perl module in about
250 lines of code, including liberal comments and vertical whitespace.
It is not designed to be memory-efficient (i.e., it will slurp whole
files into memory during the B<parse> phase), the belief being that
most templates will be rather small. This makes for very fast execution.

=back

=head2 Quick Start

For those wanting to dig in, here is an absolute barebones reference.
The rest of the document is just details.

=over 4

=item *

Create a template object:

    my $tmpl = new Template::Trivial;

=item *

Tell the object where your templates are. If you don't specify a
directory, templates will be looked for in the current working
directory of the process.

    $tmpl->templates('/usr/opt/templates');

=item *

Define your template aliases and paths. These are how you will
reference your templates later on. Paths are relative to the directory
you specified in B<templates>. If an absolute path is given (the path
begins with a '/'), the path will not be modified.

    $tmpl->define( main => 'main.tmpl',
                   head => 'head.tmpl',
                   body => 'body.tmpl', );

This defines three aliases: I<main>, I<head>, and I<body>. Each of them refers
to a template file that will be loaded later and parsed.

A sample template 'main' might look like this, if these were HTML
templates:

    <html>
    {HEAD}
    {BODY}
    </html>

A sample 'body' might look like this:

    <body>
    <h2>{TITLE}</h2>

    Blah blah blah.
    </body>

=item *

Assign values to template variables. Using the above examples as
references, we might do this:

    $tmpl->assign(TITLE => "My own web page");

Template variables match the following regular expression:

    [A-Z][A-Z0-9_-]*

In English, "An uppercase letter, followed by zero or more uppercase
letters, digits, underscores, or hyphens."

=item *

Parse the templates; parsing replaces known variables in templates
with their associated ("assigned") values, and assigns the results of
that substitution to another variable. Thus, when we do this:

    $tmpl->parse(BODY => 'body');

the template file aliased by 'body' (which is 'body.tmpl') will be
scanned for template variables (e.g., {TITLE}). These variables will
be replaced with their corresponding values (e.g., "My own web page").
When all the known variables have been replaced, the resulting
template is then assigned to the template variable 'BODY'. That is,
this template:

    <body>
    <h2>{TITLE}</h2>

    Blah blah blah.
    </body>

becomes this:

    <body>
    <h2>My own web page</h2>

    Blah blah blah.
    </body>

and will be assigned to the 'BODY' template variable. Now that this
'BODY' variable has been assigned, we can parse "higher" templates
that require the 'BODY' variable (e.g., 'MAIN').

=item *

Print out the resulting template;

    print $tmpl->to_string('MAIN');

=back

That's Template::Trivial in a nutshell. Here is a complete example:

Write some templates and put them in files:

=over 4

=item I<main.tmpl>

    <html>
    {HEAD}
    {BODY}
    </html>

=item I<head.tmpl>

    <head>
    <title>{TITLE}</title>
    </head>

=item I<body.tmpl>

    <body>
    <h2>{TITLE}</h2>
    This is a {TEST}.
    </body>

=back

Now, write the program to use the templates:

    use Template::Trivial;

    my $tmpl = new Template::Trivial;
    $tmpl->define( main => 'main.tmpl',
                   head => 'head.tmpl',
                   body => 'body.tmpl' );
    $tmpl->assign(TITLE => "This is the title");
    $tmpl->assign(TEST  => "Testing 1 2 3...");
    $tmpl->parse(HEAD => 'head');
    $tmpl->parse(BODY => 'body');
    $tmpl->parse(MAIN => 'main');
    print $tmpl->to_string('MAIN');

That's it. Here's a play-by-play:

=over 4

=item

Create the Template::Trivial object:

    my $tmpl = new Template::Trivial;

=item

Tell the object where to find the templates and give aliases for the
templates. The aliases are the same pattern as variables except
lowercase letters:

    $tmpl->define( main => 'main.tmpl',
                   head => 'head.tmpl',
                   body => 'body.tmpl' );

=item

Assign some variable data:

    $tmpl->assign(TITLE => "This is the title");
    $tmpl->assign(TEST  => "Testing 1 2 3...");

=item

Parse the 'head' template (which points to F<head.tmpl>). When this
template is parsed, its contents will be saved in the 'HEAD' template
variable, which the 'main' template uses:

    $tmpl->parse(HEAD => 'head');

So the 'HEAD' variable is now:

    <head>
    <title>This is the title</title>
    </head>

=item

Parse the 'body' template. This works just like 'head'; it must be
processed before 'main' is processed, since 'main' depends on 'BODY'
to be already defined:

    $tmpl->parse(BODY => 'body');

So the 'BODY' variable is now:

    <body>
    <h2>This is the title</h2>
    This is a Testing 1 2 3....
    </body>

=item

Now parse the "top" template 'main':

    $tmpl->parse(MAIN => 'main')

We recall that the 'main' template was:

    <html>
    {HEAD}
    {BODY}
    </html>

The B<parse> method replaces the 'HEAD' and 'BODY' variables with
their contents:

    <html>
    <head>
    <title>This is the title</title>
    </head>

    <body>
    <h2>This is the title</h2>
    This is a Testing 1 2 3....
    </body>

    </html>

This new string is assigned to the variable 'MAIN' in the B<parse>
method.

=item

Print out our results:

    print $tmpl->to_string('MAIN');

=back

=head2 Core Methods

The following methods are specified in order of how they might appear
in a real program (i.e., in the order you might use them).

=over 4

=item B<new>

Create a new template object.

    my $tmpl = new Template::Trivial;

B<new> optionally takes the following arguments:

    strict => 0
    templates => '/path/to/templates'

=item B<templates>

Tells the template object where to look for templates you define in
B<from_file>.

    $tmpl->templates('/path/to/templates');

This may also be set in the constructor. The default value is the
empty string ''.

=item B<strict>

Will emit a warning when any of the following conditions occur:

  - a template alias in 'define' does not match the lowercase regular
    expression pattern: /^[a-z][a-z0-9_-]*?$/
  - a file in a 'define' statement is not a regular file or character
    special device
  - a variable in 'assign' does not match the uppercase regular
    expression pattern: /^[A-Z][A-Z0-9_-]*?$/
  - a variable in 'assign_from_file' does not match the uppercase
    regular expression pattern: /^[A-Z][A-Z0-9_-]*?$/
  - a file in an 'assign_from_file' statement is not a regular file
    or character special device
  - a variable in 'append' does not match the uppercase regular
    expression pattern: /^[A-Z][A-Z0-9_-]*?$/
  - an undefined variable is encountered in a template during 'parse'
  - an undefined variable is encountered in 'to_string'

Example:

    $tmpl->strict(0);

The I<strict> option may be set in the constructor. It defaults to
'1'.

=item B<define>

Defines a mapping of template aliases to filenames.

    $tmpl->define( main => 'main.tmpl',
                   head => '/usr/opt/tmpl/head.tmpl',
                   body => 'body.tmpl', );

The path specified by B<templates> will be prepended to the filenames
specified in B<define>, except when the filename begins with a slash
'/', in which case the absolute path will be used.

=item B<define_from_string>

Defines a mapping of template names to the contents of a string.

    $tmpl->define_from_string( footer => "created on ${DATE}" );

This is a quick way for a programmer to make a template without
writing one to file. Useful for testing or "locking away" parts of a
template set. See L</Philosophy>.

=item B<assign>

Assigns the specified string to the specified template variable.

    $tmpl->assign( FOO => 'this is foo' );

or using a "here" document:

    $tmpl->assign( FOO => <<_BLECH_ );
    This is a longer foo
    with multiple lines.
    _BLECH_

Subsequent assignments to the same template will override previous
assignments.

You can make multiple assignments in one call:

    $tmpl->assign( FOO => 'foo string',
                   BAR => 'bar string' );

You can also append a string to an existing variable by prepending a
dot to the variable:

    $tmpl->assign('.FOO' => ' and more foo');

but this is accomplished more cleanly with the B<append> method
(below). This usage is deprecated and is included chiefly for
CGI::FastTemplate compatibility (and partly for nostalgia).

=item B<assign_from_file>

Assigns the contents of a specified file to the specified variable.
Paths are relative to the value of the B<templates> method.
B<from_file> may be used multiple times, or may take several list
arguments:

    $tmpl->assign_from_file( FOO => 'foo.txt',
                             BAR => 'bar.txt' );

is the same as:

    $tmpl->assign_from_file( FOO => 'foo.txt' );
    $tmpl->assign_from_file( BAR => 'bar.txt' );

If the filename begins with a slash, the value of B<templates> will
not be prepended:

    $tmpl->assign_from_file( MAH => '/path/to/mah.txt' );

=item B<parse>

Parses the specified template and saves its results in the specified
variable.

    $tmpl->parse( MAIN => 'main' );

Multiple variable/alias pairs may be specified:

    $tmpl->parse( JOE => 'joe',
		  BOB => 'bob_file');

but the templates are not guaranteed to be parsed in the order
specified. Because of this, you should not put codependent templates
in the same parse statement.

=item B<to_string>

Returns the contents of a template variable as a string. Useful for
assignment or printing.

    print $tmpl->to_string('FOO');

=back

That concludes this example.

=head1 TO DO

We'd like to be as complete as CGI::FastTemplate sometime, but we
wanted to get this out the door. Here are some features to look for
around Q1 or Q2 of 2004.

=over 4

=item *

B<clear>

There is no "clear" method. Currently, you can use the following
equivalents:

Clear a template:

    $tmpl->define( foo => '' );
    $tmpl->define( foo => undef );

Clear a variable:

    $tmpl->assign( FOO => '' );
    $tmpl->assign( FOO => undef );

=item *

B<from_string>, B<from_file>

These would be shortcuts for B<define_from_string> and
B<assign_from_file>, but I haven't decided whether it would make
things more confusing. This is just my scratch pad, so don't mind me.

=item *

A parsed template cache that can be made dirty by assigning a new
value to one of its variables or by redefining the template. This
would be yet-another-optimization, but I'm not sure if the overhead
would kill its potential benefits. It would be worth it if parsed
templates were reused often, otherwise it's just more overhead.
Something to think about.

=item *

Add method aliases for complete CGI::FastTemplate drop-in replacement.

=back

=head1 AUTHOR

Scott Wiersdorf, E<lt>scott@perlcode.orgE<gt>

=head1 SEE ALSO

CGI::FastTemplate(3).

=cut
