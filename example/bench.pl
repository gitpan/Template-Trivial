#!/usr/local/bin/perl -w
use strict;
use Benchmark;
use blib;


timethese(50_000,
	  {
	   fasttemplate => q( fasttemplate() ),
	   trivial      => q( trivial() ),
	  }
	 );

exit;

sub fasttemplate {
    use CGI::FastTemplate;

    my $tmpl = new CGI::FastTemplate;
    $tmpl->define( main => 'main.tmpl',
		   head => 'head.tmpl',
		   body => 'body.tmpl' );

    $tmpl->assign(TITLE => "This is the title");
    $tmpl->assign(TEST  => "Testing 1 2 3...");
    $tmpl->parse(HEAD => 'head');
    $tmpl->parse(BODY => 'body');
    $tmpl->parse(MAIN => 'main');
    my $ref = $tmpl->fetch('MAIN');
}

sub trivial {
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
    my $ref = $tmpl->to_string('MAIN');
}

BEGIN {
    open FILE, ">main.tmpl"
      or die;
    print FILE <<_EOF_;
<html>
{HEAD}
{BODY}
</html>
_EOF_
    close FILE;

    open FILE, ">head.tmpl"
      or die;
    print FILE <<_EOF_;
<head>
<title>{TITLE}</title>
</head>
_EOF_
    close FILE;

    open FILE, ">body.tmpl"
      or die;
    print FILE <<_EOF_;
<body>
<h2>{TITLE}</h2>
This is a {TEST}.
</body>
_EOF_
    close FILE;
}

END {
    unlink qw(main.tmpl head.tmpl body.tmpl);
}
