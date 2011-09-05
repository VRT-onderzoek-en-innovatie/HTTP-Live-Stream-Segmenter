#!/usr/bin/perl

use strict;
use warnings;
use Data::ParseBinary;
use Data::ParseBinary::PrettyPrinter;
use Data::ParseBinary::CachingStream;

my $p = BitStruct("ADTS frame",
	BitField("Sync", 12),
	Enum(Bit("Version"), "MPEG2" => 0, "MPEG4" => 1),
	BitField("Layer", 2),
	Bit("Protection absent"),
	BitField("Profile", 2),
	BitField("Sample rate", 4),
	Bit("Private"),
	BitField("Channels", 3),
	Bit("Original/copy"),
	Bit("Home"),
	Bit("Copyright id bit"),
	Bit("Copyright id start"),
	BitField("Used bytes", 13),
	BitField("Buffer fullness", 11),
	BitField("Blocks", 2),
	Bytes("Data", sub { $_->ctx->{"Used bytes"} - 7 } ),
	);

my $aac = BitStruct("AAC block",
	Enum( BitField("Syntactic element", 3),
		"Single channel element" => 0,
		"Channel pair element" => 1,
		"Coupling channel element" => 2,
		"LFE channel element" => 3,
		"Data stream element" => 4,
		"Program config element" => 5,
		"Fill element" => 6,
		"Terminate" => 7,
		_default_ => $DefaultPass),
	Value("Data and possibly other elements", "TODO"), # TODO
	);

my $fh;
if( @ARGV ) {
	open $fh, "<", $ARGV[0] or die "Couldn't open file ${ARGV[0]}";
} else {
	$fh = \*STDIN;
}
binmode $fh;

my $stream = CreateStreamReader(Caching => CreateStreamReader(File => $fh) );

my $count = 0;
while( ! eof $fh ) {
	printf "\nPacket %d (0x%x)\n", $count, $count;

	my $t = $p->parse($stream);
	print Data::ParseBinary::PrettyPrinter::indent(1, Data::ParseBinary::PrettyPrinter::hexdump($stream->ParsedData()) );
	$stream->Flush();
	Data::ParseBinary::PrettyPrinter::pretty_print_tree($p, $t, 2);

	my $a = $aac->parse($t->{Data});
	Data::ParseBinary::PrettyPrinter::pretty_print_tree($aac, $a, 5);

	$count++;
}

