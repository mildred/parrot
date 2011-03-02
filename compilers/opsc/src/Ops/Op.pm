#! nqp
# Copyright (C) 2010, Parrot Foundation.

=begin

=head1 NAME

Ops::Op - Parrot Operation

=head1 SYNOPSIS

  use Ops::Op;

=head1 DESCRIPTION

C<Ops::Op> represents a Parrot operation (op, for short), as read
from an ops file via C<Ops::OpsFile>, or perhaps even generated by
some other means. It is the Perl equivalent of the C<op_info_t> C
C<struct> defined in F<include/parrot/op.h>.

=head2 Op Type

Ops are either I<auto> or I<manual>. Manual ops are responsible for
having explicit next-op C<RETURN()> statements, while auto ops can count
on an automatically generated next-op to be appended to the op body.

Note that F<tools/build/ops2c.pl> supplies either 'inline' or 'function'
as the op's type, depending on whether the C<inline> keyword is present
in the op definition. This has the effect of causing all ops to be
considered manual.

=head2 Op Arguments

Note that argument 0 is considered to be the op itself, with arguments
1..9 being the arguments passed to the op.

Op argument direction and type are represented by short one or two letter
descriptors.

Op Direction:

    i   The argument is incoming
    o   The argument is outgoing
    io  The argument is both incoming and outgoing

Op Type:

    i   The argument is an integer register index.
    n   The argument is a number register index.
    p   The argument is a PMC register index.
    s   The argument is a string register index.
    ic  The argument is an integer constant (in-line).
    nc  The argument is a number constant index.
    pc  The argument is a PMC constant index.
    sc  The argument is a string constant index.
    kc  The argument is a key constant index.
    ki  The argument is a key integer register index.
    kic  The argument is a key integer constant (in-line).

=head2 Class Methods

=over 4

=end

class Ops::Op is PAST::Block;

INIT {
    pir::load_bytecode("dumper.pbc");
}

=begin

=item C<new(:$code, :$type, :$name, :@args, :%flags)>

Allocates a new bodyless op. A body must be provided eventually for the
op to be usable.

C<$code> is the integer identifier for the op.

C<$type> is the type of op (see the note on op types above).

C<$name> is the name of the op.

C<@args> is a reference to an array of argument type descriptors.

C<$flags> is a hash reference containing zero or more I<hints> or
I<directives>.


=back

=head2 Instance Methods

=over 4

=item C<code()>

Returns the op code.

=item C<type()>

The type of the op, either 'inline' or 'function'.

=item C<name()>

The (short or root) name of the op.

=item C<full_name()>

For argumentless ops, it's the same as C<name()>. For ops with
arguments, an underscore followed by underscore-separated argument types
are appended to the name.

=item C<func_name()>

The same as C<full_name()>, but with 'C<Parrot_>' prefixed.

=end

method code($code?) { self.attr('code', $code, defined($code)) }

method type($type?) { self.attr('type', $type, defined($type)) }

method name($name?) { self.attr('name', $name, defined($name)) }

method args($args?) { self.attr('args', $args, defined($args)) }

method need_write_barrier() {
    my $need := 0;
    # We need write barriers only for (in)out PMC|STR
    for self.args -> $a {
        $need := ($a<type> eq 'STR' || $a<type> eq 'PMC')
                 && ($a<direction> eq 'out' || $a<direction> eq 'inout');
        return $need if $need;
    }
    $need;
}

method arg_types($args?)  {
    my $res := self.attr('arg_types', $args, defined($args));

    return list() if !defined($res);
    pir::does__IPS($res, 'array') ?? $res !! list($res);
}

method arg_dirs($args?)   { self.attr('arg_dirs', $args, defined($args)) }

method arg_type($arg_num) {
    my @arg_types := self.arg_types;
    @arg_types[$arg_num];
}

method full_name() {
    my $name      := self.name;
    my @arg_types := self.arg_types;

    #say("# $name arg_types " ~ @arg_types);
    join('_', $name, |@arg_types);
}

method func_name($trans) {
    return $trans.prefix ~ self.full_name;
}


=begin

=item C<flags()>

Sets the op's flags.  This returns a hash reference, whose keys are any
flags (passed as ":flag") specified for the op.

=end

method flags(%flags?) { self.attr('flags', %flags, defined(%flags)) }

=begin

=item C<body($body)>

=item C<body()>

Sets/gets the op's code body.

=end

method body() {
    my $res := '';
    for @(self) -> $part {
        if pir::defined($part) {
            $res := $res ~ $part<inline>;
        }
    }
    $res;
}

=begin

=item C<jump($jump)>

=item C<jump()>

Sets/gets a string containing one or more C<op_jump_t> values joined with
C<|> (see F<include/parrot/op.h>). This indicates if and how an op
may jump.

=end

method jump($jump?)   { self.attr('jump', $jump, defined($jump)) }

=begin

=item C<add_jump($jump)>

=item C<add_jump($jump)>

Add a jump flag to this op if it's not there already.

=end

method add_jump($jump) {
    my $found_jump := 0;

    unless self.jump { self.jump(list()) }

    for self.jump {
        if $_ eq $jump { $found_jump := 1 }
    }

    unless $found_jump {
        self.jump.push($jump);
    }
}

=begin

=item C<get_jump()>

=item C<get_jump()>

Get the jump flags that apply to this op.

=end

method get_jump() {

    if self.jump {
        return join( '|', |self.jump );
    }
    else {
        return '0';
    }
}

=begin

=item C<source($trans, $op)>

Returns the L<C<body()>> of the op with substitutions made by
C<$trans> (a subclass of C<Ops::Trans>).

=end

method source( $trans ) {

    my $prelude := $trans.body_prelude;
    return $prelude ~ self.get_body( $trans );
}

=begin

=item C<get_body($trans)>

Performs the various macro substitutions using the specified transform,
correctly handling nested substitutions, and repeating over the whole string
until no more substitutions can be made.

C<VTABLE_> macros are enforced by converting C<<< I<< x >>->vtable->I<<
method >> >>> to C<VTABLE_I<method>>.

=end

method get_body( $trans ) {

    my %context := hash(
        trans => $trans,
        level => 0,
    );

    #work through the op_body tree
    self.join_children(self, %context);
}

# Recursively process body chunks returning string.
our multi method to_c(PAST::Val $val, %c) {
    $val.value;
}

our multi method to_c(PAST::Var $var, %c) {
    if ($var.isdecl) {
        my $res := $var.vivibase ~ ' ' ~ $var<pointer> ~ ' ' ~ $var.name;

        if my $arr  := $var<array_size> {
            $res := $res ~ '[' ~ $arr ~ ']';
        }

        if my $expr := $var.viviself {
            $res := $res ~ ' = ' ~ self.to_c($expr, %c);
        }
        $res;
    }
    elsif $var.scope eq 'keyed' {
        self.to_c($var[0], %c) ~ '[' ~ self.to_c($var[1], %c) ~ ']';
    }
    elsif $var.scope eq 'register' {
        my $n := +$var.name;
        %c<trans>.access_arg( self.arg_type($n - 1), $n);
    }
    else {
        # Just ordinary variable
        $var.name;
    }
}

our %PIROP_MAPPING := hash(
    :shr('>>'),
    :shl('<<'),

    :shr_assign('>>='),
    :shl_assign('<<='),

    :le('<='),
    :ge('>='),
    :lt('<'),
    :gt('>'),

    :arrow('->'),
    :dotty('.'),
);

our method to_c:pasttype<inline> (PAST::Op $chunk, %c) {
    return $chunk.inline;
}

our method to_c:pasttype<macro> (PAST::Op $chunk, %c) {
    my $name     := $chunk.name;
    my $children := self.join_children($chunk, %c);

    my $trans    := %c<trans>;

    #pir::say('children ' ~ $children);
    my $ret := Q:PIR<
        $P0 = find_lex '$trans'
        $P1 = find_lex '$name'
        $S0 = $P1
        $P1 = find_lex '$children'
        %r  = $P0.$S0($P1)
    >;
    #pir::say('RET ' ~ $ret);
    return $ret;
}

our method to_c:pasttype<macro_define> (PAST::Op $chunk, %c) {
    my @res;
    @res.push('#define ');
    #name of macro
    @res.push($chunk[0]);
    
    @res.push(self.to_c($chunk<macro_args>, %c)) if $chunk<macro_args>;
    @res.push(self.to_c($chunk<body>, %c))       if $chunk<body>;

    join('', |@res);
}


our method to_c:pasttype<macro_if> (PAST::Op $chunk, %c) {
    my @res;

    @res.push('#if ');
    # #if isn't parsed semantically yet.
    @res.push($chunk[0]);
    #@res.push(self.to_c($trans, $chunk[0]));
    @res.push("\n");

    # 'then'
    @res.push(self.to_c($chunk[1], %c));

    # 'else'
    @res.push("\n#else\n" ~ self.to_c($chunk[2], %c)) if $chunk[2];

    @res.push("\n#endif\n");


    join('', |@res);
}
our method to_c:pasttype<call> (PAST::Op $chunk, %c) {
    join('',
        $chunk.name,
        '(',
        # Handle args.
        self.join_children($chunk, %c, ', '),
        ')',
    );
}

our method to_c:pasttype<if> (PAST::Op $chunk, %c) {
    my @res;

    if ($chunk<ternary>) {
        @res.push(self.to_c($chunk[0], %c));
        @res.push(" ? ");
        # 'then'
        @res.push(self.to_c($chunk[1], %c));
        # 'else'
        @res.push(" : ");
        @res.push(self.to_c($chunk[2], %c));
    }
    else {
        @res.push('if (');
        @res.push(self.to_c($chunk[0], %c));
        @res.push(") ");

        # 'then'
        # single statement. Make it pretty.

        @res.push(self.to_c($chunk[1], %c));

        # 'else'
        if $chunk[2] {
            @res.push("\n");
            @res.push(indent(%c));
            @res.push("else ");
            @res.push(self.to_c($chunk[2], %c));
        }
    }

    join('', |@res);
}

our method to_c:pasttype<while> (PAST::Op $chunk, %c) {
    join('',
        'while (',
        self.to_c($chunk[0], %c),
        ') ',
        self.to_c($chunk[1], %c),
    );
}

our method to_c:pasttype<do-while> (PAST::Op $chunk, %c) {
    join('',
        'do ',
        self.to_c($chunk[0], %c),
        ' while (',
        self.to_c($chunk[1], %c),
        ');',
    );
}

our method to_c:pasttype<for> (PAST::Op $chunk, %c) {
    join('',
        'for (',
        $chunk[0] ?? self.to_c($chunk[0], %c) !! '',
        '; ',
        $chunk[1] ?? self.to_c($chunk[1], %c) !! '',
        '; ',
        $chunk[2] ?? self.to_c($chunk[2], %c) !! '',
        ') ',
        self.to_c($chunk[3], %c),
    );
}

our method to_c:pasttype<switch> (PAST::Op $chunk, %c) {
    join('',
        'switch (',
        self.to_c($chunk[0], %c),
        ') {',
        "\n",
        self.to_c($chunk[1], %c),
        "\n",
        indent(%c),
        "}",
    );
}

our method to_c:pasttype<undef> (PAST::Op $chunk, %c) {
    my $pirop := $chunk.pirop;

    if $pirop {
        # Some infix stuff
        if $pirop eq ',' {
            self.join_children($chunk, %c, ', ');
        }
        elsif $pirop eq '=' {
              self.to_c($chunk[0], %c)
            ~ ' = '
            ~ self.to_c($chunk[1], %c)
        }
        elsif ($pirop eq 'arrow') || ($pirop eq 'dotty') {
              self.to_c($chunk[0], %c)
            ~ %PIROP_MAPPING{$pirop}
            ~ self.to_c($chunk[1], %c)
        }
        elsif $chunk.name ~~ / infix / {
              '('
            ~ self.to_c($chunk[0], %c)
            ~ ' ' ~ (%PIROP_MAPPING{$pirop} // $pirop) ~ ' '
            ~ self.to_c($chunk[1], %c)
            ~ ')';
        }
        elsif $chunk.name ~~ / prefix / {
              '('
            ~ (%PIROP_MAPPING{$pirop} // $pirop)
            ~ self.to_c($chunk[0], %c)
            ~ ')';
        }
        elsif $chunk.name ~~ / postfix / {
              '('
            ~ self.to_c($chunk[0], %c)
            ~ (%PIROP_MAPPING{$pirop} // $pirop)
            ~ ')';
        }
        else {
            _dumper($chunk);
            pir::die("Unhandled chunk for pirop");
        }
    }
    elsif $chunk.returns {
        # Handle "cast"
        join('',
            '(',
            $chunk.returns,
            ')',
            self.to_c($chunk[0], %c),
        );
    }
    elsif $chunk<control> {
        $chunk<control>;
    }
    elsif $chunk<label> {
        # Do nothing. Empty label for statement.
        "";
    }
    else {
        _dumper($chunk);
        pir::die("Unhandled chunk");
    }
}

our multi method to_c(PAST::Op $chunk, %c) {
    my @res;

    @res.push($chunk<label> ~ "\n" ~ indent(%c)) if $chunk<label>;

    my $type := $chunk.pasttype // 'undef';
    my $sub  := pir::find_sub_not_null__ps('to_c:pasttype<' ~ $type ~ '>');

    @res.push('(') if $chunk<wrap>;
    @res.push($sub(self, $chunk, %c));
    @res.push(')') if $chunk<wrap>;

    @res.join('');
}

our multi method to_c(PAST::Stmts $chunk, %c) {
    %c<level>++ unless $chunk[0] ~~ PAST::Block;

    my @children := list();
    for @($chunk) {
        @children.push(indent($_, %c)) unless $_ ~~ PAST::Block;

        @children.push(self.to_c($_, %c));
        @children.push(";") if need_semicolon($_);
        @children.push("\n");
    }
    %c<level>-- unless $chunk[0] ~~ PAST::Block;
    join('', |@children);
}

our multi method to_c(PAST::Block $chunk, %c) {
    # Put newline after variable declarations.
    my $need_space := need_space($chunk[0]);

    my @children := list();
    @children.push(indent($chunk, %c) ~ $chunk<label> ~ "\n" ~ indent(%c)) if $chunk<label>;

    %c<level>++;

    @children.push("\{\n");

    for @($chunk) {
        if $need_space && !need_space($_) {
            # Hack. If this $chunk doesn't need semicolon it will put newline before
            @children.push("\n");
            $need_space := 0;
        }

        @children.push(indent($_, %c));
        @children.push(self.to_c($_, %c));
        @children.push(need_semicolon($_) ?? ";" !! "\n");
        @children.push("\n");
    }

    %c<level>--;
    @children.push(indent(%c));
    @children.push("}");

    join('', |@children);
}

sub need_space($past) {
    ($past ~~ PAST::Var) && $past.isdecl;
}

sub need_semicolon($past) {
    return 0 if $past ~~ PAST::Block;
    return 1 unless $past ~~ PAST::Op;

    my $pasttype := $past.pasttype;
    return 1 unless $pasttype;
    return 0 if $pasttype eq 'if';
    return 0 if $pasttype eq 'for';
    return 0 if $pasttype eq 'while';
    return 0 if $pasttype eq 'do-while';
    return 0 if $pasttype eq 'switch';

    return 1;
}


# Stub!
our multi method to_c(String $str, %c) {
    $str;
}

=begin

=item C<size()>

Returns the op's number of arguments. Note that this also includes
the op itself as one argument.

=end

method size() {
    return pir::does__IPs(self.args, 'array') ?? +self.args + 1 !! 2;
}

method join_children (PAST::Node $node, %c, $joiner?) {
    @($node).map(-> $_ { self.to_c($_, %c) }).join($joiner // '');
}

our multi sub indent($chunk, %c) {
    pir::repeat(' ', %c<level> * 4 - ($chunk<label> ?? 2 !! 0));
}

our multi sub indent(%c) {
    pir::repeat(' ', %c<level> * 4);
}


=begin

=back

=head1 SEE ALSO

=over 4

=item C<Ops::OpsFile>

=item C<Ops::OpTrans>

=item F<tools/build/ops2c.pl>

=back

=head1 HISTORY

Author: Gregor N. Purdy E<lt>gregor@focusresearch.comE<gt>

Migrate to NQP: Vasily Chekalkin E<lt>bacek@bacek.comE<gt>

=end

1;

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: ft=perl6 expandtab shiftwidth=4:

