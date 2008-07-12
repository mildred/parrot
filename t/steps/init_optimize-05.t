#! perl
# Copyright (C) 2007, The Perl Foundation.
# $Id$
# init_optimize-05.t

use strict;
use warnings;
use Test::More tests =>  10;
use Carp;
use lib qw( lib t/configure/testlib );
use_ok('config::init::defaults');
use_ok('config::init::optimize');
use Parrot::Configure;
use Parrot::Configure::Options qw( process_options );
use Parrot::Configure::Test qw( test_step_thru_runstep);

my $args = process_options(
    {
        argv => [q{--optimize}],
        mode => q{configure},
    }
);

my $conf = Parrot::Configure->new();

test_step_thru_runstep( $conf, q{init::defaults}, $args );

my ( $task, $step_name, $step, $ret );
my $pkg = q{init::optimize};

$conf->add_steps($pkg);
$conf->options->set( %{$args} );
$task        = $conf->steps->[-1];
$step_name   = $task->step;

$step = $step_name->new();
ok( defined $step, "$step_name constructor returned defined value" );
isa_ok( $step, $step_name );


$conf->data->set('gccversion' => '3.3');
$ret = $step->runstep($conf);
ok( defined $ret, "$step_name runstep() returned defined value" );


pass("Completed all tests in $0");

################### DOCUMENTATION ###################

=head1 NAME

init_optimize-05.t - test config::init::optimize

=head1 SYNOPSIS

    % prove t/steps/init_optimize-05.t

=head1 DESCRIPTION

The files in this directory test functionality used by F<Configure.pl>.

The tests in this file test subroutines exported by config::init::optimize.

=head1 AUTHOR

James E Keenan

=head1 SEE ALSO

config::init::optimize, F<Configure.pl>.

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
