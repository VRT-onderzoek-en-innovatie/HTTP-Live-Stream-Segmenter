#!/usr/bin/perl

use strict;
use warnings;
use Data::ParseBinary;
use Data::ParseBinary::PrettyPrinter;

sub UBFix32 { 
	return Struct($_[0],
			UBInt16("Integer part"),
			UBInt16("Decimal part"),
			Value("Value", sub { $_->ctx->{"Integer part"} + $_->ctx->{"Decimal part"} / 65536 })
			);
	}
sub UBFix16 {
	return Struct($_[0],
			UBInt8("Integer part"),
			UBInt8("Decimal part"),
			Value("Value", sub { $_->ctx->{"Integer part"} + $_->ctx->{"Decimal part"} / 256 })
			);
}


my $unknown_box = Bytes("Unknown box", sub { $_->ctx->{"Box length"} - 8; } );

sub boxes {
	my ($name, $boxes, $ctx_level, $extra_overhead) = @_;
	$ctx_level = 1 unless defined $ctx_level;
	$extra_overhead = 0 unless defined $extra_overhead;

	return RepeatUntil( sub { my $len = $_->ctx($ctx_level)->{"Box length"} - 8 - $extra_overhead;
		                      for my $box (@{$_->ctx}) {
								  $len -= $box->{"Box length"};
							  }
							  $len == 0;
							},
			Struct($name,
				UBInt32("Box length"),
				String("Box type", 4),
				Switch("Data", sub { $_->ctx->{"Box type"} },
					$boxes,
					default => $unknown_box
				),
			)
		);
}

my %top_level;
$top_level{free} = Bytes("Free space box", sub { $_->ctx->{"Box length"} - 8; } );
$top_level{ftyp} = Struct("File identification box",
				String("Main type", 4),
				UBInt32("Main type revision value"),
				Array( sub { $_->ctx(1)->{"Box length"}/4 - 2 - 2}, String("Used technology", 4))
			);
$top_level{mdat} = Struct("Media data box", Padding(sub { $_->ctx(1)->{"Box length"} - 8 }) );
my %moov; $top_level{moov} = boxes("Movie (presentation) box", \%moov);
my %moof; $top_level{moof} = boxes("Movie Fragment box", \%moof);

$moov{mvhd} = Struct("Movie header box",
				Const(UBInt8("Version"), 0),
				Bytes("Flags", 3),
				UBInt32("Create timestamp"),
				UBInt32("Modify timestamp"),
				UBInt32("Time units per second"),
				UBInt32("Time length"),
				UBFix32("Playback speed"),
				UBFix16("Volume"),
				Bytes("reserved", 10),
				Struct("Window geometry matrix",
					UBFix32("A"),UBFix32("B"),UBFix32("U"),
					UBFix32("C"),UBFix32("D"),UBFix32("V"),
					UBFix32("X"),UBFix32("Y"),UBFix32("W"),
				),
				UBInt32("Quicktime preview start time"),
				UBInt32("Quicktime preview duration"),
				UBInt32("Quicktime still poster time"),
				UBInt32("Quicktime selection start time"),
				UBInt32("Quicktime selection duration"),
				UBInt32("Quicktime current time"),
				UBInt32("Next/new track ID"),
			);
my %moov_trak; $moov{trak} = boxes("Track (element) box", \%moov_trak);
my %moov_udta; $moov{udta} = boxes("User data box", \%moov_udta);

$moov_trak{tkhd} = Struct("Track header",
				Const(UBInt8("Version"), 0),
				Bytes("Flags", 3),
				UBInt32("Create timestamp"),
				UBInt32("Modify timestamp"),
				UBInt32("Track ID"),
				Bytes("reserved_0", 8),
				UBInt32("Duration"),
				UBInt32("reserved_1"),
				SBInt16("Position (front to back)"),
				SBInt16("Alternate/other track ID"),
				UBFix16("Volume"),
				UBInt16("reserved_2"),
				Struct("Window geometry matrix",
					UBFix32("A"),UBFix32("B"),UBFix32("U"),
					UBFix32("C"),UBFix32("D"),UBFix32("V"),
					UBFix32("X"),UBFix32("Y"),UBFix32("W"),
				),
				UBInt32("Width"),
				UBInt32("Height"),
			);
my %moov_trak_mdia; $moov_trak{mdia} = boxes("Media (stream) box", \%moov_trak_mdia);

#$moov_trak_mdia{mdhd} = Struct("Media (stream) header box",
#				Byte("Version"),
#				Bytes("Flags", 3),
#				UBInt32("Create timestamp"),
#				UBInt32("Modify timestamp"),
#				UBInt32("Samplerate/framerate"),
#				UBInt32("Duration"),
#				UBInt16("Language code"),
#				SBInt16("Quicktime quality"),
#			);
$moov_trak_mdia{hdlr} = Struct("Handler reference",
				Byte("Version"),
				Bytes("Flags", 3),
				String("Quicktime type", 4),
				String("Media type", 4),
				String("Quicktime manufacturer", 4),
				UBInt32("reserved_0"),
				UBInt32("reserved_1"),
				Bytes("unknown", sub { $_->ctx(1)->{"Box length"} - 8 - 24; } ),
			);
my %moov_trak_mdia_minf; $moov_trak_mdia{minf} = boxes("Media (stream) information box", \%moov_trak_mdia_minf);

$moov_trak_mdia_minf{smhd} = Struct("Sound media (stream) info header box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBFix16("Balance"),
				UBInt16("reserved"),
			);
my %moov_trak_mdia_minf_dinf; $moov_trak_mdia_minf{dinf} = boxes("Data (locator) information box", \%moov_trak_mdia_minf_dinf);
my %moov_trak_mdia_minf_stbl; $moov_trak_mdia_minf{stbl} = boxes("Sample (framing info) table box", \%moov_trak_mdia_minf_stbl);

my %moov_trak_mdia_minf_dinf_dref; $moov_trak_mdia_minf_dinf{dref} = Struct("Data reference box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Number of references"),
				boxes("Data reference box", \%moov_trak_mdia_minf_dinf_dref, 2, 8),
			);

$moov_trak_mdia_minf_stbl{stsd} = Struct("Sample description box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Number of descriptions"),
				UBInt32("Description length"),
				String("Format", 4),
				Switch("Description", sub { $_->ctx->{"Format"} }, {
						"mp4a" => Struct("MP4A Description",
									Bytes("reserved", 6),
									UBInt16("Data reference index"),
									UBInt16("QUICKTIME audio encoding version"),
									UBInt16("QUICKTIME audio encoding revision"),
									String("QUICKTIME audio encoding vendor", 4),
									UBInt16("Audio channels"),
									UBInt16("Audio sample size"),
									UBInt16("QUICKTIME audio compression id"),
									UBInt16("QUICKTIME audio packet size"),
									UBFix32("Audio sample rate"),
									Bytes("Rest", sub { $_->ctx(1)->{"Description length"} - 8 - 28 }), #TODO
								),
					}, default => Bytes("Unknown description", sub { $_->ctx->{"Description length"} - 8 }),
					),
			);
$moov_trak_mdia_minf_stbl{stts} = Struct("Decoding time to sample box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Entry count"),
				Array( sub { $_->ctx->{"Entry count"} }, Struct("Decoding time delta",
					UBInt32("Sample count"),
					UBInt32("Delta"),
				)),
			);
$moov_trak_mdia_minf_stbl{ctts} = Struct("Composition time to sample box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Entry count"),
				Array( sub { $_->ctx->{"Entry count"} }, Struct("Composition time - Decoding time",
					UBInt32("Sample count"),
					UBInt32("Delta"),
				)),
			);
$moov_trak_mdia_minf_stbl{stsc} = Struct("Sample to chunk box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Number of blocks"),
				Array( sub { $_->ctx->{"Number of blocks"} }, Struct("Block map",
					UBInt32("First chunk"),
					UBInt32("Samples per chunk"),
					UBInt32("Description index")
				))
			);
$moov_trak_mdia_minf_stbl{stsz} = Struct("Sample size box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Overall sample size [B]"),
				UBInt32("Entry count"),
				Array( sub { $_->ctx->{"Entry count"} },
					UBInt32("Sample size [B]")
				)
			);
$moov_trak_mdia_minf_stbl{stco} = Struct("Chunk offset box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Entry count"),
				Array( sub { $_->ctx->{"Entry count"} },
					UBInt32("Chunk offset in file [B]")
				)
			);
$moov_trak_mdia_minf_stbl{stss} = Struct("Sync sample box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Entry count"),
				Array( sub { $_->ctx->{"Entry count"} },
					UBInt32("Sample number")
				)
			);

my %moov_udta_meta; $moov_udta{meta} = Struct("ISO/IEC 14496-12 element meta data box",
				Byte("Version"),
				Bytes("Flags", 3),
				boxes("ISO/IEC 14496-12 element meta data box", \%moov_udta_meta, 2, 4),
			);

$moov_udta_meta{hdlr} = Struct("Handler reference ISO/IEC 14496-12",
				UBInt8("Version"),
				Bytes("Flags", 3),
				String("Quicktime type", 4),
				String("Subtype", 4),
				String("reserved_0", 4),
				UBInt32("reserved_1"),
				UBInt32("reserved_2"),
				CString("Component name"),
				Bytes("unknown", sub { $_->ctx(1)->{"Box length"} - 8 - 24 - length($_->ctx->{"Component name"}) - 1; } ),
			);
my %moov_udta_meta_ilst; $moov_udta_meta{ilst} = boxes("APPLE item list box", \%moov_udta_meta_ilst);

my %moov_udta_meta_ilst__too; $moov_udta_meta_ilst{"\xa9too"} = boxes("Encoder", \%moov_udta_meta_ilst__too);

$moov_udta_meta_ilst__too{data} = Struct("Data box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("reserved"),
				Bytes("Data", sub { $_->ctx(1)->{"Box length"} - 16 } ),
			);

$moof{mfhd} = Struct("Movie Fragment Header box",
				Byte("Version"),
				Bytes("Flags", 3),
				UBInt32("Sequence number"),
			);
my %moof_traf; $moof{traf} = boxes("Track Fragment box", \%moof_traf);

$moof_traf{tfhd} = Struct("Track Fragment Header box",
				Byte("Version"),
				BitStruct("Flags",
						BitField("unknown_1", 7),
						Bit("Duration in empty"),
						BitField("unknown_2", 10),
						Bit("Default sample flags present"),
						Bit("Default sample size present"),
						Bit("Default sample duration present"),
						Bit("unknown_3"),
						Bit("Sample description index present"),
						Bit("Base data offset present"),
					),
				UBInt32("Track ID"),
				If( sub { $_->ctx->{Flags}->{"Base data offset present"} }, UBInt64("Base data offset")),
				If( sub { $_->ctx->{Flags}->{"Sample description index present"} }, UBInt32("Sample description index")),
				If( sub { $_->ctx->{Flags}->{"Default sample duration present"} }, UBInt32("Default sample duration")),
				If( sub { $_->ctx->{Flags}->{"Default sample size present"} }, UBInt32("Default sample size")),
				If( sub { $_->ctx->{Flags}->{"Default sample flags present"} }, UBInt32("Default sample flags")),
			);
$moof_traf{trun} = Struct("Track Fragment Run box",
				Byte("Version"),
				BitStruct("Flags",
						BitField("unknown_1", 12),
						Bit("Sample composition time offset present"),
						Bit("Sample flags present"),
						Bit("Sample size present"),
						Bit("Sample duration present"),
						BitField("unknown_2", 5),
						Bit("First Sample Flags Present"),
						Bit("unknown_3"),
						Bit("Data Offset Present")
					),
				UBInt32("Sample count"),
				If( sub { $_->ctx->{Flags}->{"Data Offset Present"} }, SBInt32("Data offset")),
				If( sub { $_->ctx->{Flags}->{"First Sample Flags Present"} }, UBInt32("First Sample Flags")),
				Array( sub { $_->ctx->{"Sample count"} }, Struct("Sample", 
						If( sub { $_->ctx(2)->{Flags}->{"Sample duration present"} }, UBInt32("Sample duration")),
						If( sub { $_->ctx(2)->{Flags}->{"Sample size present"} }, UBInt32("Sample size")),
						If( sub { $_->ctx(2)->{Flags}->{"Sample flags present"} }, UBInt32("Sample flags")),
						If( sub { $_->ctx(2)->{Flags}->{"Sample composition time offset present"} }, UBInt32("Sample composition time offset")),
					)),
			);

my $box = Struct("Box",
		UBInt32("Box length"),
		String("Box type", 4),
		Switch("Data", sub { $_->ctx->{"Box type"} },
			\%top_level,
			default => $unknown_box
			),
	);


my $fh;
if( @ARGV ) {
	open $fh, "<", $ARGV[0] or die "Couldn't open file ${ARGV[0]}";
} else {
	$fh = \*STDIN;
}
binmode $fh;

my $stream = CreateStreamReader(File => $fh);

while( ! eof $fh ) {
	my $t = $box->parse($stream);
	Data::ParseBinary::PrettyPrinter::pretty_print_tree($box, $t);
}

# vim: ts=4:sw=4
