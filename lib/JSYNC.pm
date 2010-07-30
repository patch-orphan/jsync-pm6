module JSYNC;

use JSON::Tiny;

my $next_anchor;
my $seen;

sub dump ($object, Bool $pretty?) is export {
    # TODO: add pretty support when added to JSON
    $next_anchor = 1;
    $seen = {};
    my $repr = _represent($object);
    my $jsync = to-json($repr);
    return $jsync;
}

sub load ($jsync) is export {
    $seen = {};
    my $repr = from-json($jsync);
    my $object = _construct($repr);
    return $object;
}

# FIXME: incomplete translation to P6
sub _info ($_*) {
    if $_[0] ~~ Glob { # FIXME: Glob in not correct
        (\$_[0] . "") =~ /^ [ ( .+ ) '=' ]? ( GLOB ) '(' ( 0x .* ) ')' $/
            or die "Can't get info for '$_[0]'";
        return $2, $1.lc, $0 || '';
    }
    if not ref($_[0]) {
        return Mu, 'scalar', Mu;
    }
    "$_[0]" =~ /^ [ ( .+ ) '=' ]? ( HASH | ARRAY ) '(' ( 0x .* ) ')' $/
        or die "Can't get info for '$_[0]'";
    return $2, $1.lc, $0 || '';
}

# FIXME: translate to P6
sub _represent {
    my $node = shift;
    my $repr;
    my ($id, $kind, $class) = _info($node);
    if ($kind eq 'scalar') {
        if (not defined $node) {
            return undef;
        }
        return _escape($node);
    }
    if (my $info = $seen->{$id}) {
        if (not $info->{anchor}) {
            $info->{anchor} = $next_anchor++ ."";
            if ($info->{kind} eq 'hash') {
                $info->{repr}{'&'} = $info->{anchor};
            }
            else {
                unshift @{$info->{repr}}, '&' . $info->{anchor};
            }
        }
        return "*" . $info->{anchor};
    }
    my $tag = _resolve_to_tag($kind, $class);
    if ($kind eq 'array') {
        $repr = [];
        $seen->{$id} = { repr => $repr, kind => $kind };
        @$repr = map { _represent($_) } @$node;
        if ($tag) {
            unshift @$repr, "!$tag";
        }
    }
    elsif ($kind eq 'hash') {
        $repr = {};
        $seen->{$id} = { repr => $repr, kind => $kind };
        for my $k (keys %$node) {
            $repr->{_represent($k)} = _represent($node->{$k});
        }
        if ($tag) {
            $repr->{'!'} = $tag;
        }
    }
    elsif ($kind eq 'glob') {
        $class ||= 'main';
        $repr = {};
        $repr->{PACKAGE} = $class;
        $repr->{'!'} = '!perl/glob:';
        for my $type (qw(PACKAGE NAME SCALAR ARRAY HASH CODE IO)) {
            my $value = *{$node}{$type};
            $value = $$value if $type eq 'SCALAR';
            if (defined $value) {
                if ($type eq 'IO') {
                    my @stats = qw(device inode mode links uid gid rdev size
                                   atime mtime ctime blksize blocks);
                    undef $value;
                    $value->{stat} = {};
                    map {$value->{stat}{shift @stats} = $_} stat(*{$node});
                    $value->{fileno} = fileno(*{$node});
                    {
                        local $^W;
                        $value->{tell} = tell(*{$node});
                    }
                }
                $repr->{$type} = $value;
            }
        }

    }
    else {
        # XXX [$id, $kind, $class];
        die "Can't represent kind '$kind'";
    }
    return $repr;
}

sub _construct ($repr) {
    my $node;
    my ($id, $kind, $class) = _info($repr);
    if $kind eq 'scalar' {
        if not $repr.defined {
            return undef;
        }
        if $repr =~ /^ '*' ( \S+ ) $/ {
            return $seen{$0};
        }
        return _unescape($repr);
    }
    if $kind eq 'hash' {
        $node = {};
        if $repr<&> {
            my $anchor = $repr<&>;
            $repr.delete('&');
            $seen{$anchor} = $node;
        }
        if $repr<!> {
            my $class = _resolve_from_tag($repr<!>);
            $repr.delete('!');
            # FIXME: P5 -> P6
            #bless $node, $class;
        }
        for $repr.keys -> $k {
            $node{_unescape($k)} = _construct($repr{$k});
        }
    }
    elsif $kind eq 'array' {
        $node = [];
        if $repr.elems and $repr[0].defined and $repr[0] =~ /^ '!' ( .* ) $/ {
            my $class = _resolve_from_tag($0);
            $repr.shift;
            # FIXME: P5 -> P6
            #bless $node, $class;
        }
        if $repr.elems and $repr[0] and $repr[0] =~ /^ '&' ( \S+ ) $/ {
            $seen{$0} = $node;
            $repr.shift;
        }
        $node = map {_construct($_)} @$repr;
    }
    return $node;
}

sub _resolve_to_tag ($kind, $class) {
    return $class && "!perl/$kind\:$class";
}

sub _resolve_from_tag ($tag) {
    $tag =~ m{^ '!perl/' [ hash | array | object ] ':' ( \S+ ) $}
        or die "Can't resolve tag '$tag'";
    return $0;
}

sub _escape ($string) {
    $string =~ s/^ ( '.'* <[!&*%]> ) /.$0/;
    return $string;
}

sub _unescape ($string) {
    $string =~ s/^ '.' ( '.'* <[!&*%]> ) /$0/;
    return $string;
}

=head1 NAME

JSYNC - JSON YAML Notation Coding

=head1 STATUS

This is a very early release of JSYNC, and should not be used at all
unless you know what you are doing.

Supported so far:
- dump and load of the basic JSON model
- dump and load of duplicate references
- dump and load recursive references
- dump and load typed mappings and sequences
- escaping of special keys and values
- dump globs
- add json pretty printing

=head1 SYNOPSIS

    use JSYNC;

    my $object = <any perl expression>
    my $jsync = JSYNC::dump($object, {pretty => 1});
    $object = JSYNC::load($jsync);

=head1 DESCRIPTION

JSYNC is an extension of JSON that can serialize any data objects.

See http://www.jsync.org/

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2010. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
