package nca3parse;
use v5.14;

sub _num {
    my $x = shift;
    $x =~ /#(\d+)/ or return $x;
    return $1;
}


sub make_identifier {
    my $s = shift;
    state %done;
    my $str = shift;
    $str =~ tr/A-Z/a-z/;
    $str =~ tr/a-z0-9_ //dc;
    $str =~ s/ /-/g;
    my $check = $str;
    my $i = 2;
    while (exists($done{$check})) {
        $check = "$str-$i";
        $i++;
    }
    $str = $check;
    $done{$str}++;
    return $str;
}

sub caption_to_refs {
    my $s = shift;
    my $caption = shift;
    my $r = shift;
    $r->{refs} ||= [];
    my ($new, $refs) = $s->endnote_to_tbib($caption);
    push @{ $r->{refs} }, @$refs;

    # remove endnote markup and create ref_src field
    if ($caption =~ /\((Figure source:|Data from|Figure and data from|Photo credits:) (.+)\)/) {
        my $ref_src = $2;
        $ref_src =~ s/\{  (  [^}]+   )  \}//xg;
        $r->{ref_src} = $ref_src;
    }
    $r->{caption} = $caption;
}

# turn endnote notation to tbib notation
# or extract existing tbib refs.
# returns new text and an arrayref of refs
sub endnote_to_tbib {
    my $s = shift;
    my $text = shift;
    my $found = [];

    # endnote record ids
    while ($text =~ s/\{  (  [^}]+  )+  \}/join "", map qq[<tbib>]._num($_).qq[<\/tbib>], split ';', $1/xeg) {
            my $refs = $1;
            for my $ref (split ';', $1) {
                $ref =~ /#(\d+)$/;
                push @$found, { record_number => $1, text => $ref };
            }
    }

    # tbib uuids
    while ($text =~ m[<tbib>([a-z0-9-]+)</tbib>]g) {
            my $uuid = $2;
            push @$found, { reference_identifier => $1 };
    }

    return ($text, $found);
}


1;

