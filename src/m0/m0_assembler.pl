#! perl
# Copyright (C) 2011, Parrot Foundation.

=head1 NAME

src/m0/m0_assembler.pl - M0 Assembler Prototype

=head1 SYNOPSIS

    % m0_assembler.pl foo.m0

=head1 DESCRIPTION

Assembles M0 source code into bytecode which can be run by an M0 interpreter.

=cut

use strict;
use warnings;
use feature 'say';
use autodie qw/:all/;
use File::Slurp qw/slurp/;
use Data::Dumper;

my $file = shift || die "Usage: $0 foo.m0";
my $file_metadata = {
    total_chunks => 0,
};


assemble($file);

sub assemble {
    my ($file) = @_;

    my $ops      = parse_op_data();
    my $source   = slurp($file);
    $source      = remove_junk($source);
    my $version  = parse_version($source);
    my $chunk    = parse_next_chunk($source);
    my $bytecode = generate_bytecode($chunk);
}

sub parse_op_data {
    my $ops;
    while (<DATA>) {
        chomp;
        my ($num, $name) = split / /, $_;
        $ops->{$name} = $num;
    }
    say "Parsed data for " . scalar(keys %$ops) . " ops";
    return $ops;
}

sub generate_bytecode {
    my ($chunk) = @_;

    my $b = $chunk->{bytecode};

    # iterate over textual representation of bytecode
    # use variable table to generate binary bytecode
    my @lines = split /\n/, $b;
    for my $line (@lines) {
        if ($line =~ m/^(?<opname>\S+)\s+(?<arg1>\S+),(?<arg2>\S+),(?<arg3>\S+)\s+$/) {
        } else {
            say "Invalid M0 bytecode segment: $line";
        }
    }
}

sub opname_to_num {
    my ($ops, $opname) = @_;

    return $ops->{$opname};
}

sub parse_version {
    my ($source) = @_;
    if ($source =~ /\.version\s+(?<version>\d+)/) {

    } else {
        say "Invalid M0: No version";
        exit 1;
    }
    say "Parsing M0 v" . $+{version};

    return $+{version};
}

sub parse_next_chunk {
    my ($source) = @_;
    $file_metadata->{total_chunks}++;
    say "Parsing chunk #" . $file_metadata->{total_chunks};

    if ( $source =~ /\.chunk\n\.variables\n(?<variables>.*)\n\.metadata\n(?<metadata>.*)\.bytecode\n(?<bytecode>.*)/ms ) {
        # captures are in %+
    } else {
        print "Invalid M0 at chunk " . $file_metadata->{total_chunks};
        exit 1;
    }
    # force a hash ref via the magic plus
    return +{ %+ };
}

# This cleans M0 code of comments and unnecessary whitespace
sub remove_junk {
    my ($source) = @_;

    # Remove comments and lines that are solely whitespace
    $source =~ s/^(#.*|\s+)$//mg;

    # Remove repeated newlines
    $source =~ s/^\n+//mg;

    return $source;
}

__DATA__
0x00 noop
0x01 goto
0x02 goto_if_eq
0x03 goto_cs
0x04 add_i
0x05 add_n
0x06 sub_i
0x07 sub_n
0x08 mult_i
0x09 mult_n
0x0A div_i
0x0B div_n
0x0C mod_i
0x0D mod_n
0x0E iton
0x0F ntoi
0x10 ashr
0x11 lshr
0x12 shl
0x13 and
0x14 or
0x15 xor
0x16 set
0x17 set_mem
0x18 get_mem
0x19 set_var
0x1A csym
0x1B ccall_arg
0x1C ccall_ret
0x1D ccall
0x1E print_s
0x1F print_i
0x20 print_n
0x21 alloc
0x22 free
0x23 exit