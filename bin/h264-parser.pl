#!/usr/bin/perl

use strict;
use warnings;
use Data::ParseBinary;
use Data::ParseBinary::PrettyPrinter;
use Data::ParseBinary::CachingStream;

my $p = BitStruct("NAL unit",
			UBInt32("Length"),
			Const(Bit("forbidden_zero_bit"), 0),
			BitField("nal_ref_idc", 2),
			Enum(BitField("nal_unit_type", 5),
					"Unspecified" => 0,
					"Coded slice of a non-IDR picture" => 1,
					"Coded slice data partition A" => 2,
					"Coded slice data partition B" => 3,
					"Coded slice data partition C" => 4,
					"Coded slice of an IDR picture" => 5,
					"Supplemental enhancement information (SEI)" => 6,
					"Sequence parameter set" => 7,
					"Picture parameter set" => 8,
					"Access unit delimiter" => 9,
					"End of sequence" => 10,
					"End of stream" => 11,
					"Filler data" => 12,
					"Sequence parameter set extension" => 13,
					"Prefix NAL unit in scalable extension" => 14,
					"Subset sequence parameter set" => 15,
					"Coded slice in scalable extension" => 20,
					_default_ => $DefaultPass,
				),
			Value("SVC extension header present", sub{
					return 1 if $_->ctx->{nal_unit_type} eq "Prefix NAL unit in scalable extension";
					return 1 if $_->ctx->{nal_unit_type} eq "Coded slice in scalable extension";
					return 0; } ),
			If( sub{ $_->ctx->{"SVC extension header present"} },
				Bytes("SVC extension header", 3)),
			Padding( sub{ my $l = $_->ctx->{Length} - 1; # "RBSP with emulation prevention"
				$l -= 3 if $_->ctx->{"SVC extension header present"};
				$l; }),
		);

my $fh;
if( @ARGV ) {
	open $fh, "<", $ARGV[0] or die "Couldn't open file ${ARGV[0]}";
} else {
	$fh = \*STDIN;
}
binmode $fh;

my $stream = CreateStreamReader(File => $fh);

my $buf = "";
my $count = 0;
while( ! eof $fh ) {
	$buf .= chr(Byte("b")->parse($stream));
	if( substr($buf, -3) eq "\x00\x00\x01" ) {
		# Annex B Start code
		my $n = 3;
		$n++ while( $n <= length($buf) && substr($buf, -$n-1, 1) eq "\x00" ); # trailing_zero_8bits
		substr $buf, -$n, $n, '';
		if( length($buf) ) {
			my $t = $p->parse( pack("N", length($buf)) . $buf );
			print "\nNAL unit $count\n"; $count++;
			Data::ParseBinary::PrettyPrinter::pretty_print_tree($p, $t, 1);
		}
		$buf = "";
	}
}

