#!/usr/bin/perl

use warnings;
use strict;

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
