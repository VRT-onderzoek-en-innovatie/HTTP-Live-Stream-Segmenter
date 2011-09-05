#!/usr/bin/perl

use warnings;
use strict;

use Data::ParseBinary;
use Data::ParseBinary::PrettyPrinter;
use Data::Dumper;
use Digest::CRC;
use Getopt::Long;
$Data::Dumper::Useqq = 1;

#$Data::ParseBinary::print_debug_info = 1;

sub sec2hmsd ($) {
	my ($s) = @_;
	my ($h, $m);
	$h = int($s/3600);
	$s -= $h*3600;
	$m = int($s/60);
	$s -= $m*60;
	return sprintf "%d:%02d:%06.3f", $h, $m, $s;
}

sub bcd2int ($) {
	my ($bcd) = @_;
	$bcd = ord($bcd);
	return ($bcd >> 4) * 10 + ($bcd & 0x0f);
}

my %parser;
$parser{pcr} = 	BitStruct("PCR",
				BitField("Base_H", 1),
				BitField("Base_L", 32),
				BitField("Reserved", 6),
				BitField("Extension", 9),
				Value("Timestamp", sub{ ( ($_->ctx->{Base_H}<<32)*300 + $_->ctx->{Base_L}*300 + $_->ctx->{Extension} ) / 27000000 }),
				Value("Timestamp HMS", sub{ sec2hmsd( $_->ctx->{"Timestamp"} ) }),
				);
$parser{ts_packet} = 
	BitStruct("TS packet",
		Const(Byte("Sync byte"), 0x47),
		Bit("Transport error indicator"),
		Bit("Payload unit start indicator"),
		Bit("Transport priority"),
		BitField("Packet ID", 13),
		Enum(BitField("Transport scrambling control", 2),
			"Not scrambled" => 0,
			"Reserved" => 1,
			"Scrambled, even key" => 2,
			"Scrambled, odd key" => 3,
			),
		Bit("Adaptation field present"),
		Bit("Payload present"),
		Nibble("Continuity counter"),
		If( sub{ $_->ctx->{"Adaptation field present"} },
			BitStruct("Adaptation field",
				Byte("Field length"),
				If( sub{ $_->ctx->{"Field length"} > 0 }, 
					BitStruct("Adaptation fields",
						Bit("Discontinuity indicator"),
						Bit("Random access indicator"),
						Bit("ES priority"),
						Bit("PCR present"),
						Bit("OPCR present"),
						Bit("Splicing point flag"),
						Bit("Transport private data flag"),
						Bit("Extension flag"),
						If( sub{ $_->ctx->{"PCR present"} },
							Struct("Program clock reference",
								$parser{pcr},
							)),
						If( sub{ $_->ctx->{"OPCR present"} },
							BitStruct("Original program clock reference",
								$parser{pcr},
							)),
						If( sub{ $_->ctx->{"Splicing point flag"} },
							SBInt8("Splice countdown") ),
						If( sub{ $_->ctx->{"Transport private data flag"} },
							Struct("Transport private data",
								Byte("Length"),
								Bytes("Data", sub{ $_->ctx->{"Length"} } )
							)),
						If( sub{ $_->ctx->{"Extension flag"} },
							BitStruct("Extension",
								Byte("Length"),
								Bit("Legal Time Window flag"),
								Bit("Piecewise rate flag"),
								Bit("Seamless splice flag"),
								BitField("reserved_0", 5),
								If( sub{ $_->ctx->{"Legal Time Window flag"} },
									BitStruct("Legal Time Window",
										Bit("Valid flag"),
										BitField("Offset", 15),
									)),
								If( sub{ $_->ctx->{"Piecewise rate flag"} }, 
									BitStruct("Piecewise rate",
										BitField("reserved", 2),
										BitField("Piecewise rate", 22),
									)),
								If( sub{ $_->ctx->{"Seamless splice flag"} },
									BitStruct("Seamless splice",
										BitField("Type", 4),
										BitField("DTS next AU_0", 3),
										Bit("Marker bit_0"),
										BitField("DTS next AU_1", 15),
										Bit("Marker bit_1"),
										BitField("DTS next AU_2", 15),
										Bit("Marker bit_2"),
										Value("DTS next AU", sub{ 
											($_->ctx->{"BTS next AU_0"} << 30) +
											($_->ctx->{"BTS next AU_1"} << 15) +
											($_->ctx->{"BTS next AU_2"});
											}),
									)),
								Bytes("reserved_1", sub{ my $len = $_->ctx->{"Length"};
									$len -= 1;
									$len -= 2 if $_->ctx->{"Legal Time Window flag"};
									$len -= 3 if $_->ctx->{"Piecewise rate flag"};
									$len -= 5 if $_->ctx->{"Seamless splice flag"};
									$len;
									}),
							)),
						Bytes("Stuffing", sub{ my $len = $_->ctx(1)->{"Field length"} - 1;
							$len -= 6 if $_->ctx->{"PCR present"};
							$len -= 6 if $_->ctx->{"OPCR present"};
							$len -= 1 if $_->ctx->{"Splicing point flag"};
							$len -= 1 + $_->ctx->{"Transport private data"}->{"Length"} if $_->ctx->{"Transport private data flag"};
							$len -= 1 + $_->ctx->{"Extension"}->{"Length"} if $_->ctx->{"Extension flag"};
							$len;
							}),
			)))),
		Bytes("Payload", sub{ my $len = 184; 
				$len -= 1 + $_->ctx->{"Adaptation field"}->{"Field length"} if $_->ctx->{"Adaptation field present"};
				$len; } ),
	);

$parser{descriptors} = RepeatUntil( sub{ 
						my $len = $_->ctx(1)->{"Length"};
						for my $des (@{$_->ctx}) {
							$len -= $des->{Length} + 2;
						}
						$len == 0;
					},
		Struct("Descriptor", 
			Byte("Tag"),
			Byte("Length"),
			Switch("Data", sub{ $_->ctx->{Tag} }, {
				2 => Struct("Video stream descriptor", 
						Bit("Multiple frame rate"),
						BitField("Frame rate code", 4),
						Bit("MPEG 1 only flag"),
						Bit("Constrained parameter"),
						Bit("Still picture"),
						If(sub{ $_->ctx->{"MPEG 1 only flag"} == 0 },
							BitStruct("non-MPEG 1 only fields",
								Byte("Profile and level"),
								BitField("Chroma format", 2),
								Bit("Frame rate extension"),
								BitField("reserved", 5),
							)),
					),
				3 => Struct("Audio stream descriptor", 
					Bytes("Unknown data", sub{ $_->ctx(1)->{Length} }),
					),
				6 => Struct("Data stream alignment descriptor", 
					Bytes("Unknown data", sub{ $_->ctx(1)->{Length} }),
					),
				10 => Struct("Language (ISO 639) descriptor", 
					Bytes("Unknown data", sub{ $_->ctx(1)->{Length} }),
					),
				11 => Struct("System clock descriptor", 
					Bytes("Unknown data", sub{ $_->ctx(1)->{Length} }),
					),
				12 => Struct("Multiplex buffer utilization descriptor", 
					Bytes("Unknown data", sub{ $_->ctx(1)->{Length} }),
					),
				16 => Struct("Smoothing buffer descriptor", 
					Bytes("Unknown data", sub{ $_->ctx(1)->{Length} }),
					),

				}, default => Bytes("Unknown data", sub{ $_->ctx->{Length} }),
				),
		));

$parser{CRC} = Struct("CRC",
					Value("CRC32 should be", sub { 
						my $crc = Digest::CRC->new(width=>32, init=>0xffffffff, xorout=>0x00000000,
                                 poly=>0x04C11DB7, refin=>0, refout=>0);
						$crc->add($_->{streams}->[0]->{ss}->{parsed_data});
						return "0x" . $crc->hexdigest;
					}),
					UBInt32("CRC32", 4),
					Value("CRC32 correct", sub { 
						my $crc = Digest::CRC->new(width=>32, init=>0xffffffff, xorout=>0x00000000,
                                 poly=>0x04C11DB7, refin=>0, refout=>0);
						$crc->add($_->{streams}->[0]->{ss}->{parsed_data});
						return "Correct" if $crc->digest == 0;
						return "Incorrect"
					}),
				);
$parser{"Current Next indicator"} = Enum(Bit("Current Next indicator"), "Current" => 1, "Next" =>0),
$parser{"Running status"} = Enum(BitField("Running status", 3), 
						"Undefined" => 0,
						"Not running" => 1,
						"Starts in a few seconds" => 2,
						"Pausing" => 3,
						"Running" => 4,
						_default_ => $DefaultPass);
$parser{"Free CA mode"} = Enum(Bit("Free CA mode"), "Not scrambled" => 0, "Scrambled" => 1);

$parser{table} = {};
$parser{table}->{PAT} = BitStruct("Pragram association table",
				Const(Bit("Section syntax indicator"), 1),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				UBInt16("Transport stream ID"),
				BitField("reserved_1", 2),
				BitField("Version number", 5),
				$parser{"Current Next indicator"},
				Byte("Section number"),
				Byte("Last section number"),
				Array( sub{ ( $_->ctx->{"Section length"} - 9) / 4 }, BitStruct("Program table",
					UBInt16("Pragram number"),
					BitField("reserved", 3),
					BitField("PID", 13),
					)),
				$parser{CRC},
				);
$parser{table}->{CAT} = BitStruct("Conditional access table",
				Const(Bit("Section syntax indicator"), 1),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				UBInt16("Transport stream ID"),
				BitField("reserved_1", 2),
				BitField("Version", 5),
				$parser{"Current Next indicator"},
				Byte("Section number"),
				Byte("Last section number"),
				If(sub{ $_->ctx->{"Section length"} > 9}, RepeatUntil(sub{ 
						my $len = $_->ctx(1)->{"Section length"};
						$len -= 5;
						$len -= 4; # CRC
						for my $el (@{$_->ctx}) {
							$len -= 5;
							$len -= $el->{"Length"};
						}
						$len == 0;
					}, BitStruct("Descriptor",
					Byte("Stream type"),
					BitField("reserved_0", 3),
					BitField("Elementary PID", 13),
					BitField("reserved_1", 4),
					BitField("Length", 12),
					If( sub{ $_->ctx->{Length} }, $parser{descriptors} ),
					))),
				$parser{CRC},
				);
$parser{table}->{PMT} = BitStruct("Program map table",
				Const(Bit("Section syntax indicator"), 1),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				UBInt16("Program number"),
				BitField("reserved_1", 2),
				BitField("Version number", 5),
				$parser{"Current Next indicator"},
				Byte("Section number"),
				Byte("Last section number"),
				BitField("reserved_2", 3),
				BitField("PCR PID", 13),
				BitStruct("Program info",
					BitField("reserved_3", 4),
					BitField("Length", 12),
					If( sub{ $_->ctx->{Length} }, $parser{descriptors} ),
				),
				RepeatUntil(sub{ 
						my $len = $_->ctx(1)->{"Section length"};
						$len -= 9;
						$len -= $_->ctx(1)->{"Program info"}->{"Length"},
						$len -= 4; # CRC
						for my $el (@{$_->ctx}) {
							$len -= 5;
							$len -= $el->{"Length"};
						}
						$len == 0;
					}, BitStruct("Element",
					Enum(Byte("Stream type"),
						"ITU-T Rec. H.262 | ISO/IEC 13818-2 Video or ISO/IEC 11172-2 constrained parameter video stream" => 2,
						"ISO/IEC 11172 Audio" => 3,
						"ISO/IEC 13818-3 Audio" => 4,
						"ITU-T Rec. H.222.0 | ISO/IEC 13818-1 PES packets containing private data" => 6,
						_default_ => $DefaultPass),
					BitField("reserved_0", 3),
					BitField("Elementary PID", 13),
					BitField("reserved_1", 4),
					BitField("Length", 12),
					If( sub{ $_->ctx->{Length} }, $parser{descriptors} ),
					)),
				$parser{CRC},
				);
$parser{table}->{SDT} = BitStruct("Service description table - actual transport stream",
				Const(Bit("Section syntax indicator"), 1),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				UBInt16("Transport stream ID"),
				BitField("reserved_1", 2),
				BitField("Version number", 5),
				$parser{"Current Next indicator"},
				Byte("Section number"),
				Byte("Last section number"),
				UBInt16("Original network ID"),
				Byte("reserved_2"),
				RepeatUntil(sub{ my $len = $_->ctx(1)->{"Section length"};
					$len -= 8 + 4; # header + CRC
					for my $el (@{$_->ctx}) {
						$len -= 5;
						$len -= $el->{"Length"};
					}
					$len == 0;
					},
					BitStruct("Service",
					UBInt16("Service ID"),
					BitField("reserved_0", 6),
					Bit("EIT schedule flag"),
					Bit("EIT present following flag"),
					$parser{"Running status"},
					$parser{"Free CA mode"},
					BitField("Length", 12),
					$parser{descriptors},
					)),
				$parser{CRC},
				);
$parser{MJD} = Struct("MJD datetime",
				UBInt16("MJD"),
				Bytes("UTC", 3),
				Value("UTC date-time", sub { 
						my $ya = int( ($_->ctx->{MJD} - 15078.2) / 365.25 );
						my $ma = int( ($_->ctx->{MJD} - 14956.1 - int($ya*365.25)) / 30.6001 );
						my $d = $_->ctx->{MJD} - 14956 - int($ya*365.25) - int($ma*30.6001);
						my $k = 0;
						$k = 1 if($ma == 14 || $ma == 15);
						my $y = $ya + $k + 1900;
						my $m = $ma - 1 - $k*12;
						my ($hr, $mi, $se) = map { bcd2int $_ } split //, $_->ctx->{UTC};
						return sprintf "%4d-%02d-%02d %02d:%02d:%02d", $y, $m, $d, $hr, $mi, $se;
					}) );

$parser{table}->{EIT} = BitStruct("Event information table",
				Const(Bit("Section syntax indicator"), 1),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				UBInt16("Service ID"),
				BitField("reserved_1", 2),
				BitField("Version number", 5),
				$parser{"Current Next indicator"},
				Byte("Section number"),
				Byte("Last section number"),
				UBInt16("Transport stream ID"),
				UBInt16("Original network ID"),
				Byte("Segment last section number"),
				Byte("Last table ID"),
				If( sub{ $_->ctx->{"Section length"}-11-4 > 0 }, RepeatUntil(sub{ my $len = $_->ctx(1)->{"Section length"};
					$len -= 11 + 4; # header + CRC
					for my $el (@{$_->ctx}) {
						$len -= 12;
						$len -= $el->{"Length"};
					}
					$len == 0;
					},
					BitStruct("Event",
					UBInt16("Event ID"),
					$parser{"MJD"},
					BitField("Duration", 24),
					$parser{"Running status"},
					$parser{"Free CA mode"},
					BitField("Length", 12),
					$parser{descriptors},
					))),
				$parser{CRC},
	);
$parser{table}->{TDT} = BitStruct("Time Description table",
				Const(Bit("Section syntax indicator"), 0),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				UBInt16("MJD"),
				Bytes("UTC", 3),
				Value("UTC date-time", sub { 
						my $ya = int( ($_->ctx->{MJD} - 15078.2) / 365.25 );
						my $ma = int( ($_->ctx->{MJD} - 14956.1 - int($ya*365.25)) / 30.6001 );
						my $d = $_->ctx->{MJD} - 14956 - int($ya*365.25) - int($ma*30.6001);
						my $k = 0;
						$k = 1 if($ma == 14 || $ma == 15);
						my $y = $ya + $k + 1900;
						my $m = $ma - 1 - $k*12;
						my ($hr, $mi, $se) = map { bcd2int $_ } split //, $_->ctx->{UTC};
						return sprintf "%4d-%02d-%02d %02d:%02d:%02d", $y, $m, $d, $hr, $mi, $se;
					}),
	);
$parser{sec} = Struct("Section",
		Byte("Table ID"),
		Switch("Table", sub { $_->ctx->{"Table ID"} }, {
			0x00 => $parser{table}->{PAT},
			0x01 => $parser{table}->{CAT},
			0x02 => $parser{table}->{PMT},
			0x42 => $parser{table}->{SDT},
			0x46 => $parser{table}->{SDT},
			0x4e => $parser{table}->{EIT},
			0x4f => $parser{table}->{EIT},
			0x50 => $parser{table}->{EIT},
			0x51 => $parser{table}->{EIT},
			0x52 => $parser{table}->{EIT},
			0x53 => $parser{table}->{EIT},
			0x54 => $parser{table}->{EIT},
			0x55 => $parser{table}->{EIT},
			0x56 => $parser{table}->{EIT},
			0x57 => $parser{table}->{EIT},
			0x58 => $parser{table}->{EIT},
			0x59 => $parser{table}->{EIT},
			0x5a => $parser{table}->{EIT},
			0x5b => $parser{table}->{EIT},
			0x5c => $parser{table}->{EIT},
			0x5d => $parser{table}->{EIT},
			0x5e => $parser{table}->{EIT},
			0x5f => $parser{table}->{EIT},
			0x60 => $parser{table}->{EIT},
			0x61 => $parser{table}->{EIT},
			0x62 => $parser{table}->{EIT},
			0x63 => $parser{table}->{EIT},
			0x64 => $parser{table}->{EIT},
			0x65 => $parser{table}->{EIT},
			0x66 => $parser{table}->{EIT},
			0x67 => $parser{table}->{EIT},
			0x68 => $parser{table}->{EIT},
			0x69 => $parser{table}->{EIT},
			0x6a => $parser{table}->{EIT},
			0x6b => $parser{table}->{EIT},
			0x6c => $parser{table}->{EIT},
			0x6d => $parser{table}->{EIT},
			0x6e => $parser{table}->{EIT},
			0x6f => $parser{table}->{EIT},
			0x70 => $parser{table}->{TDT},
			0xff => Struct("Padding",
				Value("Type", "Padding"),
				Bytes("Rest of packet", sub { $_->stream->Length } ),
				),
			},
			default => BitStruct("Unknown table",
				Value("Type", "Unknown table"),
				Bit("Section syntax indicator"),
				BitField("reserved_0", 3),
				BitField("Section length", 12),
				Bytes("Rest of section", sub { $_->ctx->{"Section length"} } ),
				),
			),
	);
$parser{timestamp} = BitStruct("Timestamp",
				BitField("reserved", 4),
				BitField("Timestamp_0", 3),
				Bit("marker_0"),
				BitField("Timestamp_1", 15),
				Bit("marker_1"),
				BitField("Timestamp_2", 15),
				Bit("marker_2"),
				Value("Timestamp", sub{ (($_->ctx->{"Timestamp_0"} << 30) +
										 ($_->ctx->{"Timestamp_1"} << 15) +
										 ($_->ctx->{"Timestamp_2"})) / 90000; } ),
				Value("Timestamp HMS", sub{ sec2hmsd( $_->ctx->{Timestamp} ); } ),
				);
$parser{pes} = Struct("Packetized Elementary Stream",
		Const(Bytes("Start code", 3), "\x00\x00\x01"),
		Byte("Stream ID"),
		UBInt16("Length"),
		Value("Unbound length video packet", sub { return "True" if $_->ctx->{"Length"} == 0; undef; }),
		If( sub{ my $sid = $_->ctx->{"Stream ID"};
			return 0 if $sid == 0xbc || $sid == 0xbe || $sid == 0xbf || $sid == 0xf0 || $sid == 0xf1 || $sid == 0xff || $sid == 0xf2 || $sid == 0xf8;
			1; }, BitStruct("PES data",
			BitField("reserved_0", 2),
			BitField("Scrambling control", 2),
			Bit("Priority"),
			Bit("Data alignment indicator"),
			Bit("Copyright"),
			Enum(Bit("Original or copy"), Original => 1, Copy => 0),
			Bit("PTS present"),
			Bit("DTS present"),
			Bit("ESCR present"),
			Bit("ES rate flag"),
			Bit("DSM trick mode flag"),
			Bit("Additional copy info flag"),
			Bit("CRC flag"),
			Bit("Extension flag"),
			Byte("Header data length"),
			If( sub{ $_->ctx->{"PTS present"} }, Struct("Presentation Time Stamp",
				$parser{timestamp},
				)),
			If( sub{ $_->ctx->{"DTS present"} }, Struct("Decode Time Stamp",
				$parser{timestamp},
				)),
			If( sub{ $_->ctx->{"ESCR present"} },
				Struct("Element stream clock reference",
					$parser{pcr},
				)),
			Bytes("Rest of header", sub{ my $len = $_->ctx->{"Header data length"};
					$len -= 5 if $_->ctx->{"PTS present"};
					$len -= 5 if $_->ctx->{"DTS present"};
					$len -= 5 if $_->ctx->{"ESCR present"};
					$len }), #TODO
			)),
	);

my %option;


{
	package Data::ParseBinary::Stream::BufferReader;
	our @ISA = qw{Data::ParseBinary::Stream::Reader};

	__PACKAGE__->_registerStreamType("Buffer");

	sub new {
		my ($class, $string) = @_;
		my $self = {
			data => $string,
			parsed_data => '',
		};
		return bless $self, $class;
	}

	sub ReadBytes {
	    my ($self, $count) = @_;
	    die "not enought bytes in stream" if $count > length($self->{data});
	    my $data = substr( $self->{data}, 0, $count);
		$self->{parsed_data} .= $data;
	    $self->{data} = substr( $self->{data}, $count );
	    return $data;
	}
	
	sub ReadBits {
	    my ($self, $bitcount) = @_;
	    return $self->_readBitsForByteStream($bitcount);
	}

	sub Cat {
		my ($self, $string) = @_;
		$self->{data} .= $string;
	}
	sub Clear {
		my ($self) = @_;
		$self->{data} = '';
		$self->{parsed_data} = '';
	}
	sub Flush {
		my ($self) = @_;
		$self->{parsed_data} = '';
	}
	sub Reset {
		my ($self) = @_;
		$self->{data} = $self->{parsed_data} . $self->{data};
		$self->{parsed_data} = '';
	}

	sub Length {
		my ($self) = @_;
		return length $self->{data};
	}

	sub Data {
		my ($self) = @_;
		return $self->{data};
	}
	
	sub tell { return 0; }
	
	sub isBitStream { return 0 };
}

{
	my $p;
	my %pid_type;

	my %parse_sec_buffer;
	sub parse_sec () {
		if( not defined $parse_sec_buffer{$p->{"Packet ID"}} ) {
			# synchronize to the section start
			my ($pointer) = ( $p->{"Payload"} =~ m/^(.)/ );
			$pointer = ord($pointer) + 1;
			$parse_sec_buffer{$p->{"Packet ID"}} = CreateStreamReader(Buffer => substr $p->{"Payload"}, $pointer);
		} else {
			# non-first packet
			# skip pointer byte if present
			if( $parse_sec_buffer{$p->{"Packet ID"}}->Length ) {
				print "     Section from previous packet continues here\n" if not defined $option{"dumper-format"};
			}
			$parse_sec_buffer{$p->{"Packet ID"}}->Cat( substr $p->{"Payload"}, 0, 1 ) unless $p->{"Payload unit start indicator"};
			$parse_sec_buffer{$p->{"Packet ID"}}->Cat( substr $p->{"Payload"}, 1 );
		}
		while( $parse_sec_buffer{$p->{"Packet ID"}}->Length ) {
			my $sec;
			if( not defined eval { $sec = $parser{sec}->parse( $parse_sec_buffer{$p->{"Packet ID"}} ); } ) {
				if( $@ =~ m/not enought bytes in stream/ ) {
					print "     Section continues in next packet, will decode once I get there\n" if not defined $option{"dumper-format"};
					$parse_sec_buffer{$p->{"Packet ID"}}->Reset;
					return;
				} else {
					die($@);
				}
			}
			$parse_sec_buffer{$p->{"Packet ID"}}->Flush;
			Data::ParseBinary::PrettyPrinter::pretty_print_tree($parser{sec}, $sec, 5);
			$option{limit}--;
			exit(0) if $option{limit} == 0;
		}
	}
	
	my %parse_pes_buffer;
	sub parse_pes () {
		$parse_pes_buffer{$p->{"Packet ID"}} = CreateStreamReader(Buffer => "") if not defined $parse_pes_buffer{$p->{"Packet ID"}};
		$parse_pes_buffer{$p->{"Packet ID"}}->Cat($p->{"Payload"});
		my $pes;
		if( not defined eval { $pes = $parser{pes}->parse( $parse_pes_buffer{$p->{"Packet ID"}} ); } ) {
			if( $@ =~ m/not enought bytes in stream/ ) {
				print "     PES continues in next packet, will decode once I get there\n";
				$parse_pes_buffer{$p->{"Packet ID"}}->Reset;
				return;
			} else {
				die($@);
			}
		}
		# Remove the remaining bytes from the buffer (PES-data)
		$parse_pes_buffer{$p->{"Packet ID"}}->Clear();
		# and signal parse() to wait for Payload-unit-start-flag
		$pid_type{$p->{"Packet ID"}} = undef;

		Data::ParseBinary::PrettyPrinter::pretty_print_tree($parser{pes}, $pes, 5);
		$option{limit}--;
		exit(0) if $option{limit} == 0;
	}
	
	sub parse() {
		my $packet;
		my $count = -1;
	
		$pid_type{8191} = "PADDING";
		while( $option{"ts-limit"} != 0 && read $option{input}, $packet, 188 ) {
			$count++;
			$p = $parser{ts_packet}->parse($packet);
			next if defined( $option{pid}) and not defined $option{pid}->{$p->{"Packet ID"}};
			$option{"ts-limit"}--;
			if( not defined $option{"dumper-format"} ) {
				printf "\nPacket %d (0x%x)\n", $count, $count;
				print Data::ParseBinary::PrettyPrinter::indent(1, Data::ParseBinary::PrettyPrinter::hexdump($packet));
			}
			Data::ParseBinary::PrettyPrinter::pretty_print_tree($parser{ts_packet}, $p, 2);
			if( defined $pid_type{$p->{"Packet ID"}} ) {
				# seen this PID before
				parse_sec if $pid_type{$p->{"Packet ID"}} eq "SEC";
				parse_pes if $pid_type{$p->{"Packet ID"}} eq "PES";
				print "     PADDING\n" if $pid_type{$p->{"Packet ID"}} eq "PADDING";
			} else {
				# Try to identify if this is a SEC or PES stream
				if( ! $p->{"Payload unit start indicator"} ) {
					print Data::ParseBinary::PrettyPrinter::indent(1, "");
					next;
				}
				if( $p->{"Payload"} =~ m/^\x00\x00\x01/ ) {
					$pid_type{$p->{"Packet ID"}} = "PES";
					parse_pes;
				} else {
					$pid_type{$p->{"Packet ID"}} = "SEC";
					parse_sec;
				}
			}
		}
	}
}

sub demux() {
	my %file;
	my $packet;
	my $count = 0;
	my %pid;
	while( $option{"ts-limit"} != 0 && read $option{input}, $packet, 188 ) {
		print "$count\r";
		my $p = $parser{ts_packet}->parse($packet);
		next if defined( $option{pid}) and not defined $option{pid}->{$p->{"Packet ID"}};
		$count++;
		$option{"ts-limit"}--;
		if( not exists $file{$p->{"Packet ID"}} ) {
			open my $fh, ">", $option{output} . "." . $p->{"Packet ID"} or die("Couldn't open demux output file");
			binmode $fh;
			$file{$p->{"Packet ID"}} = $fh;
		}
		if( $option{"demux-es"} ) {
			if( ! defined $pid{$p->{"Packet ID"}} ) {
				next unless $p->{"Payload unit start indicator"};
				$pid{$p->{"Packet ID"}} = CreateStreamReader(Buffer => "");
			}
			if( $p->{"Payload unit start indicator"} ) {
				# start of a PES packet, parse the header
				# write out what we have till now
				print { $file{$p->{"Packet ID"}} } $pid{$p->{"Packet ID"}}->Data;
				$pid{$p->{"Packet ID"}}->Clear();
				$pid{$p->{"Packet ID"}}->Cat($p->{"Payload"});
				# read off the header
				my $h = $parser{pes}->parse($pid{$p->{"Packet ID"}});
			} else {
				# just append
				$pid{$p->{"Packet ID"}}->Cat($p->{"Payload"});
			}
		} else {
			print { $file{$p->{"Packet ID"}} } $packet;
		}
	}
	print "$count\n";
}

sub remux() {
	my $packet;
	my ($cin, $cout) = (0,0);
	open my $fh, ">", $option{output} . ".remux" or die("Couldn't open demux output file");
	binmode $fh;
	while( $option{"ts-limit"} && read $option{input}, $packet, 188 ) {
		print "$cout/$cin\r";
		my $tree = $parser{ts_packet}->parse($packet);
		$cin++;
		next if defined( $option{pid}) and not defined $option{pid}->{$tree->{"Packet ID"}};
		$cout++;
		$option{"ts-limit"}--;
		if( defined $option{"map-pid"}->{$tree->{"Packet ID"}} ) {
			$tree->{"Packet ID"} = $option{"map-pid"}->{$tree->{"Packet ID"}};
			$packet = $parser{ts_packet}->build($tree);
		}
		if( defined $option{"replace-pid"}->{$tree->{"Packet ID"}} ) {
			print $fh $option{"replace-pid"}->{$tree->{"Packet ID"}};
		} else {
			print $fh $packet;
		}
	}
	print "$cout/$cin\n";
}

sub list_pids() {
	my %pid;
	my $packet;
	my $count = 0;
	while( $option{"ts-limit"} && read $option{input}, $packet, 188 ) {
		print "Parsed $count packets\r"; $count++;
		my $tree = $parser{ts_packet}->parse($packet);
		$pid{$tree->{"Packet ID"}}++;
		$option{"ts-limit"}--;
	}
	my $total = 0;
	$total += $_ for values %pid;
	print "\n";
	for my $pid (sort keys %pid) {
		printf "0x%04x (%4d) : %5d packets (%5.1f%%)\n", $pid, $pid, $pid{$pid}, $pid{$pid}*100/$total;
	}
}

sub muxstat() {
	my $packet;
	my %pid;
	my $col = 0;
	my $count = -1;

	while( read $option{input}, $packet, 188 ) {
		$count++;
		last if $option{"ts-limit"} != -1 and $count > $option{"ts-limit"};
		my $p = $parser{ts_packet}->parse($packet);
		next if defined( $option{pid}) and not defined $option{pid}->{$p->{"Packet ID"}};
		
		if( not defined $pid{$p->{"Packet ID"}} ) {
			# try to identify packet type
			next unless $p->{"Payload unit start indicator"};
			$pid{$p->{"Packet ID"}} = {};
			if( $p->{"Payload"} =~ m/^\x00\x00\x01/ ) {
				$pid{$p->{"Packet ID"}}->{type} = "PES";
			} else {
				$pid{$p->{"Packet ID"}}->{type} = "SEC";
			}
		}

		my ($pcr, $pts, $dts);
		$pcr = $p->{"Adaptation field"}->{"Adaptation fields"}->{"Program clock reference"}->{"PCR"}->{"Timestamp"};
		if ( $pid{$p->{"Packet ID"}}->{type} eq "PES" ) {
			if( $p->{"Payload unit start indicator"} ) {
				my $pes = $parser{pes}->parse($p->{"Payload"});
				$pts = $pes->{"PES data"}->{"Presentation Time Stamp"}->{"Timestamp"}->{"Timestamp"};
				$dts = $pes->{"PES data"}->{"Decode Time Stamp"}->{"Timestamp"}->{"Timestamp"};
			}
		} elsif( $pid{$p->{"Packet ID"}}->{type} eq "SEC" ) {
			# TODO
		}

		if( defined $pcr || defined $pts || defined $dts ) {
			$pid{$p->{"Packet ID"}}->{col} = $col++ unless defined $pid{$p->{"Packet ID"}}->{col};
			print "$count\t", ( "undef\tundef\tundef\t" x $pid{$p->{"Packet ID"}}->{col} ),
				(defined $pcr ? $pcr : "undef"), "\t",
				(defined $dts ? $dts : "undef"), "\t",
				(defined $pts ? $pts : "undef"),
				( "\tundef\tundef\tundef" x ( $col-1 - $pid{$p->{"Packet ID"}}->{col} )),
				"\n";
		}
	}

	print STDERR "plot ";
	my $sep = "";
	while( my ($k, $v) = each(%pid) ) {
		next unless defined $v->{col};
		print STDERR $sep, "'___' using 1:", ($v->{col}*3+2), " title '$k PCR', ",
					"'___' using 1:", ($v->{col}*3+3), " title '$k DTS', ",
					"'___' using 1:", ($v->{col}*3+4), " title '$k PTS'";
		$sep = ", ";
	}
	print STDERR "\n";
}

sub usage() {
	#        00000000011111111112222222222333333333344444444445555555555666666666677777777778
	#        12345678901234567890123456789012345678901234567890123456789012345678901234567890
	print	"Usage: $0 action [options]\n",
			"\n",
			"Actions:\n",
			"  help             Prints this message\n",
			"  parse            Parses the stream and produces a human readable decode\n",
			"  list-pids        Stripped down version of parse: only prints the PIDs found\n",
			"                   in the stream along with their occurence count.\n",
			"  muxstat          Shows mux statistics such as bitrate of the different PIDs\n",
			"  demux            Demultiplex (a part of) the TS into its components.\n",
			"  remux            Remultipex (a part of) the TS into a new TS. Useful for\n",
			"                   filtering out some PIDs. Note that this will NOT rewrite\n",
			"                   the Service Information tables!\n",
			"\n",
			"Global options (valid for all actions):\n",
			"  --input f        Specifies where to get the input from. Default is stdin.\n",
			"  --skip-bytes n   Specifies how many bytes to ignore. This is useful if the\n",
			"                   stream starts in the middle of a packet. n should prabably\n",
			"                   be smaller than 188, but this is no requirement.\n",
			"                   This should be specified _after_ --input to be of any use.\n",
			"\n",
			"parse options:\n",
			"  --pid p          Ignore all PIDs but these listed. Multiple --pid options\n",
			"                   are allowed.\n",
			"  --ts-limit n     Stop after decoding n TS-packet\n",
			"  --limit n        Stop after decoding n elements (either Sections or PES-\n",
			"                   packets)\n",
			"  --dumper-format  Dumps the parsed output in perl's Dumper format. This might\n",
			"                   be useful to edit the data and reprocess it.\n",
			"\n",
			"demux options:\n",
			"  --pid p          Only demux these PIDs. Multiple --pid options are allowed\n",
			"  --demux-es       Remove the TS and PID header, resulting in an Elementary\n",
			"                   stream.\n",
			"  --ts-limit n     Stop after demuxing n TS-packet\n",
			"\n",
			"remux options:\n",
			" All options are optional. However, using remux without any of them is fairly\n",
			" pointless, since this will result in an identical copy of the source-file.\n",
			"  --pid p          Include these PIDs in the output stream. Multiple --pid\n",
			"                   options are allowed. [default: all]\n",
			"  --map-pid o=n    Change PID when copying packets from o[ld] to n[ew].\n",
			"                   Note that --map-pid is done AFTER --pid, i.e. --pid handles\n",
			"                   on OLD PIDs\n",
			"  --replace-pid p=f\n",
			"                   Replaces a packet with PID p with the contents of file f.\n",
			"                   No checks are performed whatsoever. The file should probably\n",
			"                   by a multiple of 188 bytes in length, but this is not enforced.\n",
			"                   --replace-pid handles after --map-pid, i.e. on NEW PIDs.\n",
			"  --ts-limit n     Stop after remuxing n TS-packet\n",
			"\n",
			"muxstat options:\n",
			"  --pid p          Only generate statistics for these PIDs\n",
			"  --ts limin n     Stop after parsing n TS_packets\n",
			"\n";
}

if( @ARGV == 0 ) { usage(); exit(1); }
my $action = shift @ARGV;
$option{input} = \*STDIN; binmode $option{input};
$option{output} = 'ts';
$option{"ts-limit"} = -1;
$option{limit} = -1;
$option{"demux-es"} = 0;
$option{"replace-pid"} = {};
die() unless GetOptions(
	"input=s" => sub { $option{output} = $_[1];
		open $option{input}, "<", $_[1] or die("Could not open input file \"${_[1]}\"");
		binmode $option{input}; },
	"skip-bytes=i" => sub { read $option{input}, my $dummy, $_[1]; }, 
	"pid=i" => sub { $option{pid} = {} if not defined $option{pid}; $option{pid}->{$_[1]} = 1; },
	"ts-limit=i" => sub { $option{"ts-limit"} = $_[1]; },
	"limit=i" => sub { $option{limit} = $_[1]; },
	"demux-es" => sub{ $option{"demux-es"} = 1; },
	"dumper-format" => sub{ $option{"dumper-format"} = 1; },
	"map-pid=s%" => \$option{"map-pid"},
	"replace-pid=s" => sub{ 
		my ($p, $f) = split /=/, $_[1], 2;
		open my $fh, "<", $f; binmode $fh;
		local $/;
		$f = <$fh>;
		$option{"replace-pid"}->{$p} = $f;
		},
	);
if( scalar @ARGV ) {
	print STDERR "Warning: unknown items remaining on command line, ignoring: ", join(' ', @ARGV), "\n";
}

if(    $action eq 'parse' ) { parse(); }
elsif( $action eq 'list-pids' )	{ list_pids(); }
elsif( $action eq 'demux' )		{ demux(); }
elsif( $action eq 'remux' )		{ remux(); }
elsif( $action eq 'muxstat' )	{ muxstat(); }
else { usage(); exit(1); }


# vim: set ts=4 sw=4:
