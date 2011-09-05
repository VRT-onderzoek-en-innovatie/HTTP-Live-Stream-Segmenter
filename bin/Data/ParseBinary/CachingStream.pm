#!/usr/bin/perl

use warnings;
use strict;

package Data::ParseBinary::CachingStream;

our @ISA = qw{Data::ParseBinary::Stream::Reader};

__PACKAGE__->_registerStreamType("Caching");

sub new {
	my ($class, $substream) = @_;
	my $self = {
		substream => $substream,
		parsed_data => '',
		position => 0
	};
	return bless $self, $class;
}

sub ReadBytes {
	my ($self, $count) = @_;
	
	if( $count > length($self->{parsed_data})-$self->{position} ) {
		my $remaining = $self->{position} + $count - length($self->{parsed_data});
		$self->{parsed_data} .= $self->{substream}->ReadBytes( $remaining );
	}

	my $ret = substr $self->{parsed_data}, $self->{position}, $count;
	$self->{position} += $count;
	return $ret;
}

sub ReadBits {
	my ($self, $bitcount) = @_;
	return $self->_readBitsForByteStream($bitcount);
}

sub tell {
	my ($self) = @_;
	return $self->{position};
}

sub seek { 
	my ($self, $newpos) = @_;
	$self->{position} = $newpos;
}

sub isBitStream { return 0 };

sub ParsedData {
	my ($self) = @_;
	return $self->{parsed_data};
}
sub Flush {
	my ($self) = @_;
	$self->{parsed_data} = '';
	$self->{position} = 0;
}

1;
