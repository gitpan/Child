#!/usr/bin/perl;
use strict;
use warnings;

use Test::More 0.88;
our $CLASS = 'Child';

require_ok( $CLASS );

my $child = $CLASS->new( sub {
    my $self = shift;
    $self->say( "Have self" );
    $self->say( "parent: " . $self->pid );
    my $in = $self->read();
    $self->say( $in );
}, pipe => 1 );

my $proc = $child->start;
is( $proc->read(), "Have self\n", "child has self" );
is( $proc->read(), "parent: $$\n", "child has parent PID" );
{
    local $SIG{ALRM} = sub { die "non-blocking timeout" };
    alarm 5;
    ok( !$proc->is_complete, "Not Complete" );
    alarm 0;
}
$proc->say("XXX");
is( $proc->read(), "XXX\n", "Full IPC" );
ok( $proc->wait, "wait" );
ok( $proc->is_complete, "Complete" );
is( $proc->exit_status, 0, "Exit clean" );

$proc = $CLASS->new( sub { sleep 100 } )->start;

my $ret = eval { $proc->say("XXX"); 1 };
ok( !$ret, "Died, no IPC" );
like( $@, qr/Child was created without IPC support./, "No IPC" );
$proc->kill(2);

$proc = $CLASS->new( sub {
    my $self = shift;
    $SIG{INT} = sub { exit( 2 ) };
    $self->say( "go" );
    sleep 100;
}, pipe => 1 )->start;

$proc->read;
sleep 1;
ok( $proc->kill(2), "Send signal" );
ok( !$proc->wait, "wait" );
ok( $proc->is_complete, "Complete" );
is( $proc->exit_status, 2, "Exit 2" );
ok( $proc->unix_exit > 2, "Real exit" );

$child = $CLASS->new( sub {
    my $self = shift;
    $self->autoflush(0);
    $self->say( "A" );
    $self->flush;
    $self->say( "B" );
    sleep 5;
    $self->flush;
}, pipe => 1 );

$proc = $child->start;
is( $proc->read(), "A\n", "A" );
my $start = time;
is( $proc->read(), "B\n", "B" );
my $end = time;

ok( $end - $start > 2, "No autoflush" );

$proc = $CLASS->new( sub {
    my $self = shift;
    $self->detach;
    $self->say( $self->detached );
}, pipe => 1 )->start;

is( $proc->read(), $proc->pid . "\n", "Child detached" );

done_testing;
