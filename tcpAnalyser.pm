#-------------------------------------------------   tcpAnalyser.pm   ------------------------------------------------------------------------

use module1; 
use module2;
use Shell qw( rm , more );


#----------------------      MAIN

my $message = "usage: perl tcpAnalyser.pm localhost tcpDumpFile version destination source_port_number dest_port_number direction interval details delete\nperl tcpAnalyser.pm -help for help\n";


$client = shift || die $message;

if( $client eq -help ) {
    print more( "readme" );
    exit;
}

$fileName = shift || die $message;

$qui = shift || die $message;
$REMOTE = shift || die $message;
$PORT1 = shift || die $message;
$PORT2 = shift || die $message;
$DIRECTION = shift || die $message;
$space = shift || die "please specify interval";
$details = shift || 0;
$delete = shift || 0;

local %hash;
local $tempTable;
local ( $host1 , $host2 , $port1 , $port2 );
local $compte = 0;
local ( %seen , %seenDest , %seenPort1 , %seenPort2 );
local @destinationTable;
local ( %port1Hash , %port2Hash );
local @addresses;


rm( "-f" , "output" );
generateHash();
analyse();

#----------------------
#----------------------- SUBS

sub generateHash {

    my ( $dest , $part1 , $part2 , $flow , @table , $h1 , $h2 , $port1 , $port2 , $key );
    
    open( readFlux , $fileName );
    
    while( $line = <readFlux> ) {
	$part1 = (split ":" , $line)[2];
	$part1 =~ /\d+\.\d+\sIP\s(.+)/;
	$flow = $1;

	@table = split " > " , $flow;
	$h1 = $table[0];
	$h2 = $table[1];
	$h1 =~ /(.+)\.(.+)/; 
	$h1 = $1;
	$port1 = $2;
	if( $port1 =~ /(\d+)/ ) {
	}
	else { 
	    $port1 = getservbyname( $port1 , "tcp" );
	}	
	
	$h2 =~ /(.+)\.(.+)/;
	$h2 = $1;
	$port2 = $2;
	if( $port2 =~ /(\d+)/ ) {
	}
	else {
	    $port2 = getservbyname( $port2 , "tcp" );
	}	

	$key = $h1 . "|" . $port1 . "|" . $h2 . "|" . $port2;
	

	$hash{ $key } .= $line;
	
	if ( $seen { $key } == 1 ) {
	}
	else {
 	    $seen { $key } = 1;
	    @ { $addresses[$compte] } = ( $h1 , $port1 , $h2 , $port2 );
	    $compte++;
	}

	
	if( $h1 eq $client ) {
	    $dest = $h2;
	}
	if( $h2 eq $client ) {
	    $dest = $h1;
	    my $temp = $port1;
	    $port1 = $port2;
	    $port2 = $temp;
	}
	if( $seenDest{ $dest } == 1 ) {
	}
	else {
	    push @destinationTable , $dest;
	    $seenDest{ $dest } = 1;
	}

	
	if( $seenPort1{ $dest }{ $port1 } == 1 ) {
	}
	else {
	    push @ { $port1Hash{ $dest } } , $port1;
	    $seenPort1{ $dest }{ $port1 } = 1;
	};

	
	if( $seenPort2{ $dest }{ $port2 } == 1 ) {
	}
	else {
	    push @ { $port2Hash{ $dest } } , $port2;
	    $seenPort2{ $dest }{ $port2 } = 1;
	};

    }
#-- TESTS   
#    foreach $element ( @destinationTable ) {
#	foreach $element2 ( @ { $port2Hash{ $element } } ) {
#	    print $element2,"\n";
#	}
#   }
#--    

#-- TESTS    
#    for( $i=0 ; $i<$compte ; $i++ ) {
#	$cle = $addresses[$i][0] . "|" . $addresses[$i][1] . "|" . $addresses[$i][2] . "|" . $addresses[$i][3] ;
#	print $hash{ $cle };
#    }

    close( readFlux );

}

sub analyse {
    
    my ( @destinations , @toDo , @portTable1 , @portTable2 );
    my ( $f1 , $f2 );
    my $file;
    
    if( $REMOTE eq "*" ) {
	@destinations = @destinationTable;
    }
    else {
	if( $seenDest{ $REMOTE } == 1 ) {
	    push @destinations , $REMOTE;
	}
	else {
	    warn "no conn. between $client and $REMOTE\n";
	}
    }
    
    foreach $h2 ( @destinations ) {
	@portTable1 = ();
	@portTable2 = ();
	
	

	if( $PORT1 eq "*" ) {
	    @portTable1 = @ { $port1Hash { $h2 } };
	}
	else {
	    if( $seenPort1{ $h2 }{ $PORT1 } == 1 ) {
		push @portTable1 , $PORT1;
	    }
	    else { 
		#warn "no conn. between $client port $PORT1 and $h2\n";
	    }
	}

	if( $PORT2 eq "*" ) {
	    @portTable2 = @ { $port2Hash { $h2 } };
	}
	else {
	    if( $seenPort2{ $h2 }{ $PORT2 } == 1 ) {
		push @portTable2 , $PORT2;
	    }
	    else { 
		#warn "no conn. between $client and $h2 port $PORT2 \n";
	    }
	}
	
	foreach $p1 ( @portTable1 ) {
	    
	    foreach $p2 ( @portTable2 ) {
		
		if( $DIRECTION eq "out" ) {
		    $f1 = $client . "|" . $p1 . "|" . $h2 . "|" . $p2;
		    if( $seen{ $f1 } == 1 ) {
			push @toDo , $f1;
		    }
		};
		if( $DIRECTION eq "in" ) {
		    $f1 = $h2 . "|" . $p2 . "|" . $client . "|" . $p1;
		    if( $seen{ $f1 } == 1 ) {
			push @toDo , $f1;
		    }
		}
		if( $DIRECTION eq "*" ) {
		    $f1 = $client . "|" . $p1 . "|" . $h2 . "|" . $p2;
		    $f2 = $h2 . "|" . $p2 . "|" . $client . "|" . $p1;
		    if( $seen{ $f1 } == 1 ) {
			push @toDo , $f1;
		    }
		    if( $seen{ $f2 } == 1 ) {
			push @toDo , $f2;
		    }
		}
	    }
	}
    }
#----- 
    my $l = scalar @toDo;
    print "$l flows analysed:\n";
    
    foreach $donnee ( @toDo ) {
	$donnee =~ /(.+)\|(.+)\|(.+)\|(.+)/;
	print "- from $1 port $2 to $3 port $4 \n" ;
    }
    print "press Enter\n";
    while( ! <STDIN> ) {
    }
    
#-----
    my $compteur = 1;
   foreach $job ( @toDo ) {
       $file = "$job";
	open( writeFlux , '>' , $file );
	print writeFlux $hash{ $job };
	close( writeFlux );
	$job =~ /(.+)\|(.+)\|(.+)\|(.+)/;
	#print $job,"\t",$space,"\t",$details"\n";
	print "-------->  FLOW$compteur  from $1 port $2 to $3 port $4 \n\n";
       $compteur++;
       if( $qui eq "al" ) {
	   open( flux2 , '>>' , "output" );
	   print flux2 ("\n-------->  FLOW$compteur  from $1 port $2 to $3 port $4 \n\n");
	   close( flux2 );
	 module2::main( $job , $space , $details );
	};
       if( $qui eq "ad" ) {
	   open( flux2 , '>>' , "output" );
	   print flux2 ("\n-------->  FLOW$compteur  from $1 port $2 to $3 port $4 \n\n");
	   close( flux2 );
	 module1::main( $job , $space , $details );
       }
       if( $delete == 1 ) {
	   rm( "-f" , "\"$job\"" );
       }
       print "press Enter\n";
       while( ! <STDIN> ) {
       }
   }
}

#---------------------------------------------------------------------------------------------------------------------------------------------

