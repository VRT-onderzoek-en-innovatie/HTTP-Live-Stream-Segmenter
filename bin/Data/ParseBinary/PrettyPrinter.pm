#!/usr/bin/perl

use warnings;
use strict;

use Data::ParseBinary;
use Data::Dumper;

package Data::ParseBinary::PrettyPrinter;

sub hexdump {
    my $offset = 0;
    my(@array,$format,$ret);
    foreach my $data (unpack("a16"x(length($_[0])/16)."a*",$_[0])) {
        my($len)=length($data);
        if ($len == 16) {
            @array = unpack('N4', $data);
            $format="0x%08x (%05d)   %08x %08x %08x %08x   %s\n";
        } else {
            @array = unpack('C*', $data);
            $_ = sprintf "%2.2x", $_ for @array;
            push(@array, '  ') while $len++ < 16;
            $format="0x%08x (%05d)" .
               "   %s%s%s%s %s%s%s%s %s%s%s%s %s%s%s%s   %s\n";
        } 
        $data =~ tr/\0-\37\177-\377/./;
        $ret .= sprintf $format,$offset,$offset,@array,$data;
        $offset += 16;
    }
	$ret .= sprintf "0x%08x (%05d) Total length\n", length($_[0]), length($_[0]);
	return $ret;
}

sub indent ($@) {
	my ($indent, @value) = @_;
	return @value if $indent == 0;

	$indent = " "x$indent;
	@value = map { s/^/$indent/gm; $_ } @value;
	return @value;
}


{
	package Data::ParseBinary::Context;
	sub new { my $self = { ctx => $_[1] }; return bless $self, $_[0]; }
	sub ctx { return $_[0]->{ctx}; }
}
sub pretty_print_tree; # recursive function needs declaration
sub pretty_print_tree {
	my ($parser, $parsed_tree, $indent_level) = @_;
	$indent_level = 0 if not defined $indent_level;
	my $indent = " "x$indent_level;

	if( ref $parser eq 'Data::ParseBinary::ConditionalRestream' ) {
		pretty_print_tree $parser->subcon, $parsed_tree, $indent_level;

	} elsif ( ref $parser eq 'Data::ParseBinary::Struct' ) {
		print $indent, $parser->{Name}, " [Struct]:\n";
		for my $i (0..@{$parser->{subs}}-1) {
			if( ref $parser->{subs}->[$i] eq 'Data::ParseBinary::Switch' ) {
				# Switch needs original context!
				pretty_print_tree $parser->{subs}->[$i], $parsed_tree, $indent_level+1;
			} else {
				pretty_print_tree $parser->{subs}->[$i], $parsed_tree->{ $parser->{subs}->[$i]->{Name} }, $indent_level+1;
			}
		}

	} elsif( ref $parser eq 'Data::ParseBinary::ConstAdapter' ) {
		print $indent, $parser->{Name}, " [Const]:\n";
		pretty_print_tree $parser->{subcon}, $parsed_tree, $indent_level+1;

	} elsif( ref $parser eq 'Data::ParseBinary::Primitive'
	      || ref $parser eq 'Data::ParseBinary::ReveresedPrimitive' ) {
		printf "%s%s [I]:    %d = 0x%x = 0%o = 0b%b\n", $indent, $parser->{Name}, $parsed_tree, $parsed_tree, $parsed_tree, $parsed_tree;

	} elsif( ref $parser eq 'Data::ParseBinary::BitField' ) {
		printf "%s%s [%db]:    0b%0" . $parser->{length} . "b = %d = 0x%x = 0%o\n", 
			$indent, $parser->{Name}, $parser->{length}, $parsed_tree, $parsed_tree, $parsed_tree, $parsed_tree;

	} elsif( ref $parser eq 'Data::ParseBinary::Enum' ) {
		print $indent, $parser->{Name}, " [Enum]:    ";
		if( defined $parser->{encode}->{$parsed_tree} ) {
			print $parser->{encode}->{$parsed_tree}, " [ = ", $parsed_tree, "]\n";
		} else {
			print $parsed_tree, " [ = Unknown ]\n";
		}

	} elsif( ref $parser eq 'Data::ParseBinary::Switch' ) {
		return if not defined $parsed_tree;
		local $_ = Data::ParseBinary::Context->new($parsed_tree);
		my $case = $parser->{keyfunc}->();
		print $indent, $parser->{Name}, " [Switch]:    ", $case, "\n";
		if( defined $parser->{cases}->{$case} ) {
			pretty_print_tree $parser->{cases}->{$case}, $parsed_tree->{$parser->{Name}}, $indent_level+1;
		} else {
			# default case
			pretty_print_tree $parser->{default}, $parsed_tree->{$parser->{Name}}, $indent_level+1;
		}

	} elsif( ref $parser eq 'Data::ParseBinary::Value' ) {
		print $indent, $parser->{Name}, " [V]:    ", $parsed_tree, "\n" if defined $parsed_tree;

	} elsif( ref $parser eq 'Data::ParseBinary::StaticField' ) {
		print $indent, $parser->{Name}, ":\n", 
			indent($indent_level+1, hexdump($parsed_tree));

	} elsif( ref $parser eq 'Data::ParseBinary::MetaField' ) {
		print $indent, $parser->{Name}, ":\n", 
			indent($indent_level+1, hexdump($parsed_tree));

	} elsif( ref $parser eq 'Data::ParseBinary::RepeatUntil' ) {
		print $indent, $parser->{Name}, " [Array, RepeatUntil]:\n";
		for my $i (0..@{$parsed_tree}-1) {
			pretty_print_tree $parser->{sub}, $parsed_tree->[$i], $indent_level+1;
		}

	} elsif( ref $parser eq 'Data::ParseBinary::MetaArray' ) {
		print $indent, $parser->{Name}, " [Array, VarLength]:\n";
		for my $i (0..@{$parsed_tree}-1) {
			pretty_print_tree $parser->{sub}, $parsed_tree->[$i], $indent_level+1;
		}

	} elsif( ref $parser eq 'Data::ParseBinary::JoinAdapter' 
	      && ref $parser->{subcon} eq 'Data::ParseBinary::MetaArray'
	      && ref $parser->{subcon}->{sub} eq 'Data::ParseBinary::StaticField') {
		print $indent, $parser->{Name}, " [String]:    ", $parsed_tree, "\n";

	} elsif( ref $parser eq 'Data::ParseBinary::CStringAdapter'
	      && ref $parser->{subcon} eq 'Data::ParseBinary::JoinAdapter'
		  && ref $parser->{subcon}->{subcon} eq 'Data::ParseBinary::RepeatUntil'
		  && ref $parser->{subcon}->{subcon}->{sub} eq 'Data::ParseBinary::StaticField' ) {
		print $indent, $parser->{Name}, " [CString]:    ", $parsed_tree, "\n";

	} elsif( ref $parser eq 'Data::ParseBinary::Padding' ) {
		# TODO: add the number of bytes skipped eval($parser->{count_code});
		print $indent, "[skipped]\n";

	} elsif( ref $parser eq 'Data::ParseBinary::Peek' ) {
		print $indent, $parser->{Name}, " [Peek]:\n";
		pretty_print_tree $parser->{subcon}, $parsed_tree, $indent_level+1;

	} else {
		print $indent, "Unknown construct in parser: ", ref $parser, "\n";
		print "DEBUG: ", main::Dumper($parser, $parsed_tree);
	}
}

1;

# vim: set ts=4 sw=4:
