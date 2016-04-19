#--------------------------------------------------------- module2.pm ------------------------------------------------------------------------

package module2;
require Exporter;

#---

sub main {

    local $dataFile = shift;
    local $interval = shift;
    local $verbose = shift || 0;
    
    local @maxSN;
    local @minSN;
    local @groupPacketList;                
    local @dupOrFill;
    
    local $previousTS = 0;
    local $currentTS = 0;
    local $count = 0;
    local $currentGroup = 0;
    local $newGroup = 0;
    local $bytes;
    local $type;
    local $sn1;
    local $sn2;
    $converted = 0;

    my $firstLine = 1;
    open( readFlux , $dataFile );
    while( $line = <readFlux> ) {
	
	chomp $line;
	@table = split " " , $line;
        if ($table[6] =~ /\[([A-Z])[.]\]/ ) {
                $type = $1;
        }
        $pt = $table[7];
        $SN = $table[8];
        #print "$pt\t", "$SN\n";
        if ( $SN =~ /(\d+)\:(\d+)/ ) {
            $sn1 = $1;
            $sn2 = $2;
            $bytes = $2-$1;
             #print "1:$sn1\t","2:$sn2\t","3:$bytes\n";
        }

	if( !($pt eq 'ack') and ($SN =~ /(\d+)\:(\d+)\((\d+)\)/) and !($type eq 'S') and ($bytes > 0) ) {
	    
	    if( $firstLine == 1 ) {
		if( $sn1 > 1 ) {
		    $sn1 = $sn1 - $sn2;
		    $sn2 = 0;
		    $converted = 1;
		};
		$firstLine--;
	    }
	    
	    $currentTS = $table[0];
	    if( $currentTS =~ /\d+\:\d+\:\d+\.\d+/ ) {
		
		if( $count == 0 ) {
		    $previousTS = $currentTS ;
		}
		&put( $count );
		$count++;
	    }
	}
    }
    
    
    close( readFlux );
    if( $verbose == 1 ) {
	&printGroup();
	print "              --------------           \n";
    }
    &printStats( $converted );
    
    
    
#-- group components
    
    sub printGroup {
	local $longueur1 = scalar @groupPacketList;
	local $longueur2 = scalar @dupOrFill;
	local $longueur = &max( $longueur1 , $longueur2 );
	for( $i=0 ; $i<$longueur ; $i++ ) {
	    print "group $i: ";
	    local $l = scalar @{ $groupPacketList[$i] };
	    for( $j=0; $j<$l ; $j++ ) {
		print $groupPacketList[$i][$j] , " | ";
	    }
	    print "\n";
	    print "group $i: ";
	    local $l = scalar @{ $dupOrFill[$i] };
	    for( $j=0; $j<$l ; $j++ ) {
		print $dupOrFill[$i][$j] , "|";
	    }
	    print "\n";
	}
    };


#-- group stats


sub printStats {
    my $flag = shift;
    my $l1 = scalar @groupPacketList;
    my $l2 = scalar @dupOrFill;
    my $numberGroups = &max( $l1 , $l2 );
    my $diffTime = 0;
    my $st1 = 0;
    my $st2 = 0;
    my $indice = 0;
    my $misOrder = "";
    my $fillString = "F";
    my $dupString = "D";
    
    open( flux1 , '>' , "temp" );
    open( flux2 , '>>' , "output" );

    for( $i=0 ; $i<$numberGroups ; $i++ ) {
	local $lowerBound;
	$misOrder="";
	$fillString="F";
	$dupString="D";
	if( $i>0 ) {
	    local @table = @maxSN[0..$i];
	    pop @table;
	    @table = sort numerically @table;
	    $lowerBound = pop @table;
	    $lowerBound = &min( $lowerBound , $minSN[$i] );
	    #print ".../n";
	}
	else {
	    $lowerBound = $minSN[$i];
	}
	local $newRangeCovered = $maxSN[$i] - $lowerBound;
	local $newDataBytes = 0;
	local $startTime = 0;
	local $endTime = 0;
	local $newPackets = scalar @{$groupPacketList[$i]} || 0;
	$lastSN = 0;
	for( $j=0 ; $j<$newPackets ; $j++ ) {
	    local $line = $groupPacketList[$i][$j];
	    $packet = (split " " , $line)[2];
	    $packet =~ /(\d+):(\d+)/ ;
	    if( ($i == 0) and ($j == 0) and ($flag == 1) ) {
		$newDataBytes += ( $2 + $1 );
	    }
	    else {
		$newDataBytes += ( $2 - $1 );
	    };
	    
	    if( $1 - $lastSN < 0 ) {
		$misOrder = "M";
	    }
	    $lastSN = $2;
	}
	#print $newDataBytes;
	local $missingDataBytes = $newRangeCovered - $newDataBytes;
	local $packet1 = $groupPacketList[$i][0];
	local $packet2 = $groupPacketList[$i][$newPackets-1];
	$startTime = ( split " " , $packet1 )[1];
	$endTime = ( split " " , $packet2 )[1];
		
	local $DOF = scalar @ { $dupOrFill[$i] };
	local $packets = $newPackets + $DOF;
	#print "$i:$packets ";
	
	if( $DOF > 0 ) { 
	    local @table1;
	    for( $j=0 ; $j<$DOF ; $j++ ) {
		local $packet = $dupOrFill[$i][$j];
		push @table1 , ( split " " , $dupOrFill[$i][$j] )[1];
	    }
	    local $MAX = $table1[$DOF-1];
	    local $MIN = $table1[0];
	    if( defined $packet1 ) {
		if( &substractTS( $endTime , $MAX ) > 0 ) {
		    $endTime =  $MAX ;
		}
	    }
	    else {
		$endTime = $MAX;
	    }
	    if( defined $packet2 ) {
		if( &substractTS( $MIN , $startTime ) > 0 ) {
		    $startTime =  $MIN ;
		}
	    }
	    else {
		$startTime = $MIN;
	    }
	}
	$elapsedTime = int ( &substractTS( $startTime , $endTime ) / 1000 );
	if( $indice == 0 ) {
	    $st1 = $startTime;
	};
	$st2 = $startTime;
	$diffTime = int ( &substractTS( $st1 , $st2 ) / 1000 );
	$st1 = $st2;
	$indice++;
      	
	for( $j=0 ; $j<$DOF ; $j++ ) {
	    local $packet = $dupOrFill[$i][$j];
	    if ( $packet =~ /DUPof(\d+)\,/ ) {
		$dupString .= " $1";
	    }
	    elsif ( $packet =~ /PUREFILLERof(\d+)\,/ ) {
		$fillString .= " $1";
	    }
	}
	
 format flux1 = 
@<<<<<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<< @<<<<<<< @<<<<<<< @<<<<< @<<<<<< @<<<<<<<<<<<<< @<<<<<<<<<<<<< @<<<<<<<<<<<<< @<<<<< @<<<<< @<
"G$i-"   "ST:$startTime"   "ET:$endTime"     "El:$elapsedTime" "GP:$diffTime" "P:$packets" "NP:$newPackets" "NRC:$newRangeCovered" "NDB:$newDataBytes" "MDB:$missingDataBytes " $fillString $dupString $misOrder   
.
 format flux2 = 
@<<<<<< @<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<<<<<<< @<<<<<<< @<<<<<<< @<<<<< @<<<<<< @<<<<<<<<<<<<< @<<<<<<<<<<<<< @<<<<<<<<<<<<< @<<<<< @<<<<< @<
"G$i-"   "ST:$startTime"   "ET:$endTime"     "El:$elapsedTime" "GP:$diffTime" "P:$packets" "NP:$newPackets" "NRC:$newRangeCovered" "NDB:$newDataBytes" "MDB:$missingDataBytes " $fillString $dupString $misOrder   
.
	write flux1;
        write flux2;
        
      }
close( flux1 );
close( flux2 );
open ( flux1 , "temp" );
print <flux1>;
close( flux1 );

}

#---------------------------------------- packet analyse ------- -------------------------------------

sub put {
    
    $c = shift;
    $checkDups = 0;
    
    
    if( $c == 0 ) {                      #initialization
	$checkDups = 0;
	$previousTS = $currentTS;
	$maxSN[ 0 ] = $sn2;          #and init max and min SN
	$minSN[ 0 ] = $sn1; 
    }
    
    local $T = &substractTS ( $previousTS , $currentTS );
    
    if( $T <= $interval ) {             #then packet will belong to the same group  
	$checkDups = 1;
	$newGroup = 0;
    }
    else {
	$newGroup = 1;
	$currentGroup += 1;                	 #then packet will belong to the next group
	$previousTS = $currentTS;
	$checkDups = 1;
	#$maxSN[ $currentGroup ] = $sn2;          #and init max and min SN
 	#$minSN[ $currentGroup ] = $sn1;          #|
    }
    
    if( $currentGroup == 0 ) {               #for the first group
	#local $currentMax = $maxSN [0];
	#local $currentMin = $minSN[0];
	
	local $dup = &detectDups( $currentGroup );
	if( $dup >= 0 ) {             #then packet is dup for the same group
	    push @ { $dupOrFill [ $currentGroup ] } , "$count $currentTS $sn1:$sn2 DUPof$currentGroup,$dup";  #put packet in dupOrFiller list for corresponding group
	    #push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2 DUPof$currentGroup,$dup"; #put packet in packet list for current group
	}
	else {
	    push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2";         #put packet in packet list for current group
	    $currentMax = $maxSN [0];
	    $currentMin = $minSN[0];
	}
	$maxSN [0] = &max( $currentMax , $sn2 );
	$minSN[0] = &min( $currentMin , $sn1 );
    }
    
    else {
	local @table = @maxSN ;
     	if( ($newGroup == 0) and ( defined $maxSN[$currentGroup]) ) {
	    pop @table;
	};
	@table = sort numerically @table;
	local $highest = pop @table;
	
	if( $sn1 >= $highest ) {                        #then packet is new to previous groups
	    if( $checkDups == 1 ) {
		local $dup = &detectDups( $currentGroup );
		if( $dup >= 0 ) {             #then packet is dup for the same group
		    push @ { $dupOrFill [ $currentGroup ] } , "$count $currentTS $sn1:$sn2 DUPof$currentGroup,$dup";  #put packet in dupOrFiller list for corresponding group
		    #push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2 DUPof$currentGroup,$dup"; #put packet in packet list for current group
		}
		else {
		    push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2";         #put packet in packet list for current grouplocal $currentMax = $maxSN[ $currentGroup ];
		    $currentMax = $maxSN[ $currentGroup ];
		    $currentMin = $minSN[ $currentGroup ];
		    if( ! defined $currentMax ) {
			$currentMax = $sn2;
		    }
		    if( ! defined $currentMin ) {
			$currentMin = $sn1;
		    }
		    $maxSN[ $currentGroup ] = &max( $currentMax , $sn2 );     #update max high new SN for current group, if necessary
		    $minSN[ $currentGroup ] = &min( $currentMin , $sn1 );    #update min low new SN for current group, if necessary
		};
	    }
	    else {
		push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2";         #put packet in packet list for current group
		$currentMax = $maxSN[ $currentGroup ];
		$currentMin = $minSN[ $currentGroup ];
		if( ! defined $currentMax ) {
		    $currentMax = $sn2;
		}
		if( ! defined $currentMin ) {
		    $currentMin = $sn1;
		}
		$maxSN[ $currentGroup ] = &max( $currentMax , $sn2 );     #update max high new SN for current group, if necessary
		$minSN[ $currentGroup ] = &min( $currentMin , $sn1 );    #update min low new SN for current group, if necessary
	    }
	   	    
	}
	
	else {                                              #then packet is dup or filler
	    local $a = &findGroup();
	    local $fillers = &detectFillers( $a );
	    if( $fillers == 1 ) {                          #then packet is a filler
		push @ { $dupOrFill [ $currentGroup ] } , "$count $currentTS $sn1:$sn2 PUREFILLERof$a,";        #put packet in dupOrFiller list for corresponding group
		#push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2 PUREFILLERof$a";
	    }
	    else {                                #then packet is a dup
		local $dup = &detectDups( $a );
		push @ { $dupOrFill [ $currentGroup ] } , "$count $currentTS $sn1:$sn2 DUPof$a,$dup";        #put packet in dupOrFiller list for corresponding group
		#push @{ $groupPacketList[ $currentGroup ] } , "$count $currentTS $sn1:$sn2 DUPof$a,$dup";
	    }
	}
    }
}

#--- find group of which packet is a filler or dup
sub findGroup {
    local @table = @maxSN;
    if( ($newGroup == 0) and ( defined $maxSN[$currentGroup]) ) {
	pop @table;
    };
    @table = sort numerically @table;
    local $length = scalar @table;
    local $group;
    for( $i=0 ; $i<$length ; $i++ ) {
	if( $sn1 < $maxSN[ $i ] ) {
	    $group = $i;
	    last;
	}
    }
    return $group;
}

#--- check if packet is a dup of one of the current group's packets
sub detectDups {
    local $group = shift;
    local $result = -1;
    $length = scalar @ { $groupPacketList[ $group ] };
    for( $i=0; $i<$length ; $i++ ) {
	local @table = split " " , $groupPacketList[ $group ][$i];
	$packet = $table[2];
	$seq1 = (split ":" , $packet)[0];
	$seq2 = (split ":" , $packet)[1];
	if( (($sn2<=$seq2) and ($sn2>$seq1)) or (($sn1<$seq2) and ($sn1>=$seq1)) ) {
	    $result = $i;
	    last;
	}
    }
    return $result;
}

#--- check if packet is a filler of a previous group
sub detectFillers {
    local $group = shift;
    local $NOT = 1;
    $length = scalar @ { $groupPacketList[ $group ] };
    for( $i=0; $i<$length ; $i++ ) {
	local @table = split " " , $groupPacketList[ $group ][$i];
	$packet = $table[2];
	$seq1 = (split ":" , $packet)[0];
	$seq2 = (split ":" , $packet)[1];
	if( ($sn1>=$seq2) or ($sn2<=$seq1)) {
	    next;
	}
	else {
	    $NOT = 0;
	    last;
	}
    }
    if( $NOT == 0 ) {
	return -1; 
	}
    else {
	return 1;
    }
}

#--- make the difference between two timestamps in microseconds
sub substractTS {
    $t1 = shift;
    $t2 = shift;
    local ( $h1 , $m1 , $s1 , $mi1 , $h2 , $m2 , $s2 , $mi2 );
    if( $t1 =~ /(\d+)\:(\d+)\:(\d+)\.(\d+)/ ) {
	$h1 = $1;
	$m1 = $2;
	$s1 = $3;
	$mi1 = $4;
    };
    if( $t2 =~ /(\d+)\:(\d+)\:(\d+)\.(\d+)/ ) {
	$h2 = $1;
	$m2 = $2;
	$s2 = $3;
	$mi2 = $4;
    }
    local $t3 = ($h2-$h1)*3600000000 + ($m2-$m1)*60000000 + ($s2-$s1)*1000000 + ($mi2-$mi1);
    return $t3;
}

#--- max between a and b
sub max {
    local $a = shift;
    local $b = shift;
    if( $a >= $b) {
	return $a;
    }
    else {
	return $b;
    }
}

#--- min
sub min {
    local $a = shift;
    local $b = shift;
    if( $a >= $b) {
	return $b;
    }
    else {
	return $a;
    }
}

#--- for sort
sub numerically { $a <=> $b;}

#--- for sort
sub separate {
    $arg = shift;
    $field = shift;
    return (split ":" , $arg )[$field];
}

#--- for sort
sub byTime {
    &separate( $a , 0 ) <=> &separate( $b , 0)
	or
	    &separate( $a , 1 ) <=> &separate( $b , 1)
		or
		    &separate( $a , 2 ) <=> &separate( $b , 2)
			or
			    (split "." , $a)[1] <=> (split "." , $b)[1];
}
}

