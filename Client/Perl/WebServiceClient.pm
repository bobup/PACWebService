#!/usr/bin/perl -w
# WebServiceClient.pm - General client PERL interface to PMS web services

# Copyright (c) 2019 Bob Upshaw and Pacific Masters.  This software is covered under the Open Source MIT License 

package WebServiceClient;

use diagnostics;
use strict;
use warnings;
use HTTP::Tiny;
use JSON::MaybeXS;
use Data::Dumper;

my $debug = 0;

# Our Web Services -
# Here is where you define a new web service.  To do so you update this block of comments to document
# your web service (below) and then add the details of your web service access further below.
# Rules:
#	1.  Every web service has a name.  For example "GetRecords" is the name of a web service.  It is
#		this name that is passed to GetData() in order to invoke the service.  The caller only knows the
#		name and parameters for that service.  They don't know the location or implementation details.
#	2.	Every web service "should" return a string - if nothing else at least a status.  The returned
#		string is enclosed in a JSON structure and returned by GetData().
#	3.	When defining a web service below you map its name to the details, which are basically the 
#		the path to the service and its domain.
#		You DON'T supply the protocol, port, query parameters, or 
#		fragment - that's all handled by GetData().
# 
#
# Existing web services (document all web services here):
#	GetRecords - takes one parameter:
#		course:  one of SCM, LCM, or SCY (case sensitive).
#		Returns a full set of PAC records for the corresponding course.
#		The records come from the PRODUCTION database.
#	GetRecords_dev - same as GetRecords above except the records come from the DEVELOPMENT database.
#
# Details of all web services here:
my %OurServices = (
	"GetRecords"		=> {
		"domain"		=>	"data.pacificmasters.org/",
		"path"			=>	"api/pacrecords/GetRecords.php"
	},
	"GetRecords_dev"	=> {
		"domain"		=>	"pacmdev.org/",
		"path"			=>	"api/pacrecords/GetRecords.php"
	},
);



#### IMPLEMENTATIONS OF WEB SERVICES:

# GetRecords - get PAC records for a specific course from the PRODUCTION database
#
sub GetRecords( $ ) {
	my( $course ) = @_;
	my $JSONdata = GetData( "GetRecords", $course );
	return $JSONdata;
}

# GetRecords_dev - get PAC records for a specific course from the DEVELOPMENT database
#
sub GetRecords_dev( $ ) {
	my( $course ) = @_;
	my $JSONdata = GetData( "GetRecords_dev", $course );
	return $JSONdata;
}



#### IMPLEMENTATION OF WEB SERVICES CORE:
my $tinyHttp = HTTP::Tiny->new( );


# GetData() - send a request to the passed URL and return with the answer.
#
# PASSED:
#	$serviceName - a standard service name known to this web service client.  Used to construct
#		the request sent to the server by using the name to index into the OurServices hash.
#	$request - details of the request sent to the server.  If an empty string then no details sent.
#
# RETURNED:
#	$result - a JSON string response from the server or a JSON string representing an error.
#		In all cases:
#			$result->{'status'} is a status code.  >=0 implies no error, <0 implies error.
#				If >=0 then it represents the number of lines in the content.
#			$result->{'error'} is an empty string if status >=0, otherwise a description of the error.
#		If status >= 0, then:
#			$result->{'content'}, if defined by the service, is the content of the service.
#
#
sub GetData( $$$ ) {
	my ($serviceName, $request) = @_;
	my $result = "";
	
	if( !defined $OurServices{$serviceName} ) {
		my $error = {
			status		=> -1,
			error		=> "Illegal service name: '$serviceName'",
		};
		$result = encode_json( $error );
	} else {
		my $fullUrl = "https://" . $OurServices{$serviceName}{"domain"} . "/" . $OurServices{$serviceName}{"path"};
		if( $request ne "" ) {
			$fullUrl .= "?$request";
		}
		
		my %callbackState = (
			"numCallbackCalls"		=> 	0,
			"numLines"				=>	0,
			"content"				=>  "",
			);
		my %options = (
			"data_callback"	=>	sub {
				ParseWebServiceResponse( \%callbackState, $serviceName, $fullUrl, $_[0], $_[1] );
			} );
	
		# issue the HTTP request and get the response:
		my $httpResponseRef = $tinyHttp->get( $fullUrl, \%options );
		# we get here under TWO conditions:
		#	- the entire response has been processed by data_callback routine and all is good, or
		#	- none (or some?) of the response has been processed and we got an error.
		# This means the httpResponse is either "OK" or some error, so, if it's an error, we'll handle
		# it here:
		if( $debug > 0 ) {
			# dump the response we fetched so we can make sure we're getting what we expect
			print "Response:\n";
			print Dumper( $callbackState{content} );
		}



#				error		=> "HTTP error: '" . $httpResponseRef->{status} . "',\n    reason: '" .
#					$httpResponseRef->{reason} . "',\n    final URL: '" . $httpResponseRef->{url} . "'\n" .
#					"    full URL: '" . $fullUrl . "'",


#				error		=> "HTTP error: '" . $httpResponseRef->{status} . "', reason: '" .
#					$httpResponseRef->{reason} . "', final URL: '" . $httpResponseRef->{url} . "', " .
#					"full URL: '" . $fullUrl . "'",



		if( !$httpResponseRef->{success} ) {
			# failure - return an error
			my $error = {
				status		=> -2,
				error		=> "HTTP error: '" . $httpResponseRef->{status} . "', reason: '" .
					$httpResponseRef->{reason} . "', final URL: '" . $httpResponseRef->{url} . "'",
			};
			$result = encode_json( $error );
		} else {
			# all of the response has been received with no errors
			my $str = {
					status		=> $callbackState{numLines},
					error		=> "",
					content		=> $callbackState{content},
				};
			
			$result = encode_json( $str );
		}
	}
		
	if( $debug > 0 ) {
		print "WebServiceClient::GetData(): return '$result'\n";
	}
	return $result;
} # end of GetData()


#				ParseWebServiceResponse( \%callbackState, $serviceName, $fullUrl, $_[0], $_[1] );
# ParseWebServiceResponse - parse the response to the request made by GetData() above.
#
# PASSED:
#	$callbackStateRef -
#	$serviceName -
#	$fullUrl -
#	$content - the chunk of data fetched from the $fullUrl
#	$httpResponseRef - reference to the http response hash
#	
#
sub ParseWebServiceResponse( $$$$$$$ ) {
	my( $callbackStateRef, $serviceName, $fullUrl, $content, $httpResponseRef ) = @_;
	my $numCallbackCalls = $callbackStateRef->{"numCallbackCalls"}+1;
	$callbackStateRef->{"numCallbackCalls"} = $numCallbackCalls;
	my $numLines = $callbackStateRef->{"numLines"};

	if( $debug ) {
		print "ParseWebServiceResponse() called:  numCallbackCalls=$numCallbackCalls,  " .
			(defined $httpResponseRef->{'success'}?$httpResponseRef->{'success'}:
			"httpResponseRef->{'success'} is undefined") . ", " .
			"numLines so far=$numLines" .
			", httpResponseRef->{'status'}=$httpResponseRef->{'status'}\n" .
			"  url='" . (defined $httpResponseRef->{'url'}?$httpResponseRef->{'url'}:
			"httpResponseRef->{'url'} is undefined") . ", " .
			"\n";
	}
	
	# before doing anything make sure we didn't get an error
	if( ((defined $httpResponseRef->{success}) && !$httpResponseRef->{'success'}) ||
		($httpResponseRef->{'status'} !~ /^2/) ) {
		# failure - display message and give up on this one
		my $error = {
			status				=> -3,
			error				=> "ParseWebServiceResponse() FAILED!! (during " .
				"callback #$numCallbackCalls), " .
				"HTTP status: '" . $httpResponseRef->{status} . "', reason: '" .
					$httpResponseRef->{reason} . "', final URL: '" . $httpResponseRef->{url} . "'",
		};
		$callbackStateRef->{content} = encode_json( $error );
	} else {
		$numLines += $content =~ tr/\n//;
		$callbackStateRef->{'numLines'} = $numLines;
		$callbackStateRef->{'content'} .= $content;
	}
} # end of ParseWebServiceResponse()






#### TESTING:


sub TestWebServices() {
	my $JSONdata = GetRecords_dev( "SCY");
	my $data = decode_json( $JSONdata );
	print "Data as a Perl object: \n";
	print Dumper( $data );
	if( $data->{'status'} > 0 ) {
		print "\n\nContent:\n";
		print $data->{'content'};
		# the content is another JSON string
		my $arrOfRecords = decode_json( $data->{'content'} );
		print "\nRecord #0:";
		print Dumper( $arrOfRecords->[0]);
		print Dumper( $arrOfRecords->[1]);
		print "\nArray of records:\n";
		print Dumper( $arrOfRecords );	
		
		
	} elsif( $data->{'status'} == 0 ) {
		print "\n\nContent is EMPTY!\n";
	} else {
		print "\n\nNo Content, error instead.  Status=" . $data->{'status'} . ", " .
			"error='" . $data->{'error'} . "'\n";
	}
}

#TestWebServices();

1;  # end of module WebServiceClient
