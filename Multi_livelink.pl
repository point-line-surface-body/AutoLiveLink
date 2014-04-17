#!/usr/bin/env perl
#
# ASB *** Team
#
# ***@alcatel-sbell.com.cn
# ***@alcatel-sbell.com.cn
#
#
# 2012/10/9 YS
# Note:  (1) https://wlsagile.app.alcatel-lucent.com:8443/browse/SWTR-2442

#
# 2012/10/17 YS
# Note:  (1) https://wlsagile.app.alcatel-lucent.com:8443/browse/SWTR-2394
#		 (2) http://umtsweb.ca.alcatel-lucent.com/wiki/bin/view/WcdmaRNC/MultiLiveLink
#
#
# 2012/11/21 YS
# Note:  (1) Apply Multi-Process to speed up MultiLiveLink
#		     Example: Download all XWOs Start:	2012_11_21_22_27_57 End  :	2012_11_21_22_37_51
#        (2) Change name from "MultiLiveLink" to "Multi_LiveLink"
# 
# [Note]
# Usage	     :  perl multi_livelink.pl YzJWdWVXRTZiblZoWVhsek1UazROeUU9
# JenKins Job:  http://rdrnagi.cn.alcatel-lucent.com:8080/view/Tools/job/MultiLiveLink
# WikiWebPage:	http://umtsweb.ca.alcatel-lucent.com/wiki/bin/view/WcdmaRNC/MultiLiveLink



use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Compare;
use File::Spec::Functions;
use File::Path;
use Time::Local;
use POSIX qw(strftime);
use MIME::Base64;

#Time
my $starttime= strftime "%Y_%m_%d_%H_%M_%S", localtime;

#Account
my $encoded=decode_base64(decode_base64($ARGV[0]));

#XWO Directory
my $XWODataPath="/net/sbardy08/rnc_log/ACE/XWODATA/";			mkdir($XWODataPath) if (! -d $XWODataPath);
my $COOKIEStore=File::Spec->catfile($XWODataPath,"COOKIEStore");	mkdir($COOKIEStore) if (! -d $COOKIEStore);
my $CSVStore   =File::Spec->catfile($XWODataPath,"CSVStore");		mkdir($CSVStore) 		if (! -d $CSVStore);

my $url="https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe";
my $urlprefix="https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\?func=ll\&objId=";


####---------------------------------------------------------------
##   Step 1
##   Create a new Cookie at the beginning of run, and display it.
####---------------------------------------------------------------
my $success=0;
my $nameforcookie = $starttime.".cookie";
my $cookie				= File::Spec->catfile($XWODataPath.$nameforcookie);

if (CreateCookie($cookie,$url)==0)
{
	print "Error when curl the webpage https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\n";
  unlink $cookie;
  $success=1;
  exit 0;
}
else
{
	print "="x80,"\nCookie Info\nName:$cookie\n\n";
	open FH,"<",$cookie || die "Cannot open Cookie file : $cookie\n";	
	print <FH>;
	close FH;
	
}


####---------------------------------------------------------------
##   Mapping
##   Create hash of RNV Load Version to CSV files, as well as to LiveLinkID
##	 V71Global
##	 V81ATT
##	 V81Global
##	 V91ATT
##	 V91Global
####---------------------------------------------------------------
#livelink webpage id
my %rnchash=(	'V71Global'=>57996986,
							'V81ATT'=>65897377,
							'V81Global'=>60998147,
							'V91ATT'=>65939307,
							'V91Global'=>65799582
						);

#csv files corresponding
my %csvhash=(   'V71Global'=>"load_xwo_ua7_Global.csv",
                'V81ATT'=>"load_xwo_ua8_ATT.csv",
                'V81Global'=>"load_xwo_ua8_Global.csv",
                'V91ATT'=>"load_xwo_ua9_ATT.csv",
                'V91Global'=>"load_xwo_ua9_Global.csv"
            );

foreach my $key (sort keys %csvhash)
{
        my $value=$csvhash{$key};
#        printf("%-14s:  %s\n",$key,$value);
}


####---------------------------------------------------------------
##	 Main
####---------------------------------------------------------------
my @childs;
my $count = 1;

print "="x80,"\n\n";
print "Multi Process .....\n"; 
print "="x80,"\n\n";
## Establish
foreach my $key (sort keys %rnchash)
{	
	my $pid = fork();
	if ($pid)
	{
	  # parent	 #print "pid is $pid, parent $$\n";
		push(@childs, $pid);
	}
	elsif ($pid == 0)
	{
		# child
		sub_routine($count,$key);
		exit 0;
	}
	else
	{
	die "!!!!couldn't fork: $!\n";
	}
	$count++;
	
}

## Wait
foreach (@childs)
{
	my $tmp = waitpid($_, 0);
	print "Process done with pid $tmp\n";

}

#----------------------------------------------------
#               END & Compute time consumed
#----------------------------------------------------

&backup($cookie) if ($success == 0);
print "\n","-"x72,"\n";
my $end_time = strftime "%Y_%m_%d_%H_%M_%S", localtime;
print "Start:\t",$starttime,"\n";
print "End  :\t",$end_time,"\n";
print "\n","-"x72,"\n";


####---------------------------------------------------------------
##   Important Sub_routine
##
####---------------------------------------------------------------

sub sub_routine
{
	my $id =shift;
	my $key=shift;
	print "="x80,"\n\n";
	printf("====Started thread %-2s : %-10s====\n",$id,$key);
	printf("%-14s:\t%s\n",$key,$rnchash{$key});
	my $xwocsvpath = File::Spec->catfile($XWODataPath,$key);						mkdir($xwocsvpath) if (! -d $xwocsvpath);
	my $csv        = File::Spec->catfile($xwocsvpath ,$csvhash{$key});
	my $xwolist    = File::Spec->catfile($xwocsvpath ,"XwoList.csv");
	my $TmpHtmlFile= File::Spec->catfile($XWODataPath,"process_".$id.".txt");	
	my $currenturl = File::Spec->catfile($urlprefix  ,$csvhash{$key});
	
	## Backup CSV
	my $csvbackup= File::Spec->catfile($CSVStore,$starttime."_".$csvhash{$key});
	copy($csv,$csvbackup);
	
	## Get HTML Content from V7/8/9 Global/ATT mainpage, Parser it and generate CSV file
	ParserHTML($rnchash{$key},$csv,$TmpHtmlFile);
	
	## Get FileId From Webpage recursively
	my %list=&GetFileIdFromWebpage($rnchash{$key},$key,$TmpHtmlFile);
	open LIST,">",$xwolist || die "Cannot write to file $xwolist :$!\n";;
	print "="x80,"\n";
	
	## if new xwo comes, download it
	foreach my $k (sort keys %list)
	{
	  next if ($list{$k} !~ /xwo$|gz$/i); #skip condition
	  next if ($list{$k} !~ /^RNC/);      #skip condition
    	  print $k,"\t",$list{$k},"\n";
	  print LIST "$k,$list{$k}\n";
		
		#download operation
		my $downdir    = $xwocsvpath;		mkdir($downdir) if (! -d $downdir);
		my $targetfile = File::Spec->catfile($downdir,$list{$k});
		
		my $xwoname=$targetfile;
		if ($targetfile =~ /(.*\.xwo)\.gz$/i)
		{
		        $xwoname=$1;	#print "\nXWO Name: $xwoname\n";
		}
		if (-e $xwoname)
		{
			chmod 0775,$xwoname;
			next; #next if $targetfile exist;
		}
		
		##download link of xwofile
		my $fileaddress="$urlprefix$k\&objAction=download";
		print "Downloading $targetfile :$fileaddress ......\n";
		system("curl -b $cookie -c $cookie -u $encoded --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$k\\&objAction=download -o $targetfile");
		`echo "$targetfile has been downloaded!"  | mail -s "#MultiLiveLink# $list{$k} is coming" sen.b.yang\@alcatel-sbell.com.cn -c rnc-sh-pave-hawk\@LIST.ALCATEL-LUCENT.COM`;
		system("gunzip","-f",$targetfile) if ( $targetfile =~ /\.gz$/);
		chmod 0775,$xwoname;
			
	}
	close LIST;


	print "====Done with thread $id====\n";
	return $id;
}



#----------------------------------------------------
#	Create Cookiesfile
#----------------------------------------------------
sub CreateCookie
{
	my ($tcookie,$weburl)=@_;
	my $output=`curl -c $tcookie -u $encoded --insecure -H "Accept-Encoding:gzip,deflate" $weburl`;
#	if ($output =~ /302 Found/i)	{	print "\nError:302\tCookie file can not be used for automation\n";	return 0;	}
#	print "========\n$output\n===========\n";
  if ($output =~ /401 Authorization Required/i)
  {
          print "\nError:401 Authorization Required\tUser's Password is wrong!\n";
          return 0;
  }
	if ($output =~ /Livelink Client Error/i)
  {
          print "\nThe Livelink Server may be down or misconfigured.\nPlease try again. If the problem persists, contact your Livelink administrator!\n";
          return 0;
  }

	if ($output =~ /a href="(.*)">here/)
	{
	        print $1,"\n";
	        $url=$1;
	        $url =~ s/\?/\\\?/g;
	        $url =~ s/%2E/\./g;
	        $url =~ s/%2F/\//g;
	        $url =~ s/%3D/=/g;
	        $url =~ s/%3F/\\\?/g;
	        $url =~ s/;/\\;/g;
	        $url =~ s/\&/\\&/g;
	        print "$url\n";
		system("curl -c $tcookie -u $encoded --insecure -H 'Accept-Encoding:gzip,deflate' $url");
		return 1;
	}	
	else
	{
		return 0;
	}
}


#----------------------------------------------------
#       backup cookie
#----------------------------------------------------
sub backup
{
        my $t_cookie=shift;
        my $backup=File::Spec->catfile($COOKIEStore,$nameforcookie);
	print "\n\nCurrentcookie :$t_cookie\n";
	print "Backup cookie :$backup\n";
	copy($t_cookie,$backup);
	unlink $t_cookie;
}

#----------------------------------------------------
#   ParserHTML SubRoutine
#----------------------------------------------------
sub ParserHTML
{
	my ($pageid,$csvfile,$TmpHtmlFile)=@_;
	my $pageurl="$urlprefix$pageid";
	printf("%-14s:\t%s\n","URL",$pageurl);
	printf("%-14s:\t%s\n","CSV",$csvfile);
	print "="x80,"\n";
	
	system("curl -b $cookie -c $cookie -o $TmpHtmlFile -u $encoded --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$pageid");
	my @array;
	open FH, "<", $TmpHtmlFile || die "Cannot read file:$!\n";
	my $flag=0;
	while(<FH>)
	{
		if ( $_ =~ /error.html/)
		{
			print "\nError: webpage may not exist!\n";
			return 1;
		}
	        next if ($_ !~ /DataStringToVariables/);
	        if ( $_ =~ /\[(.*)\]/)
	        {
	                @array = split /\},/,$1;
			$flag=1;
			last;
	        }#grep "DataStringToVariables"  | awk -F "[" '{print $2}' | awk -F "]" '{print $1}' 
	}
	close FH;
	
	if ($flag == 0 || scalar(@array) ==0 )
	{
		`cat $TmpHtmlFile`;
		print "Error:\t in curl webpage\n";
		exit;
	}
	print "Size:",scalar(@array),"\n";
	

	my @folderlist;
	my @filelist;
	my %csv;

	my $TmpCsvFile=$XWODataPath.time().".csv";

	foreach my $item (@array)
	{
	        next if ($item !~ /UA|RI|XWO/i);
		if ($item =~ /"dataId":"(\d+)".*"typeName":"(\w+)","name":"(.*)","link":"(.*)","size":"(\d+)%20(\w+)","date":"(.*)","dateReal"/)
	        {
	                my $dataId=$1;
	                my $typeName=$2;
	                my $name  =$3;
	                my $size =$5." ".$6;
	                my $date = $7;
	                $date =~ s/%2F/\//g;$date =~ s/%20/ /g;$date =~ s/%3A/:/g;
	                $name =~ s/%2E/\./g; $name =~ s/%20/ /g; $name =~ s/%2D/-/g; $name =~ s/%28/(/g; $name =~ s/%2A/\*/g; $name =~ s/%29/)/g;
	                if ($name =~ /(RNC.*V\d+).*\(.*(RI\w+)/)
	                {
	                        my $XWOname=$1;
	                        chomp($XWOname);
	                        #print "XWO     :$XWOname\n";
	                        my $XWOmatchVersion=$2;
	                        #print "Version :$XWOmatchVersion\n";
	                        my $num=0;
	                        if ($XWOname =~ /V(\d+)/)
	                        {
	                                $num=$1;
	                        }
	                        my $info=$XWOname.",".$XWOmatchVersion.",".$date;
	                        $csv{$num}=$info;
	                }
	                push @folderlist, $dataId if ($typeName =~ /Folder/i);
	                push @filelist, $dataId   if ($typeName =~ /Document/i);
	        }
	}

	## Write info into CSV
	open FH, ">", $TmpCsvFile || die "Cannot read file:$!\n";
	foreach my $key (sort {$b <=> $a} keys %csv)
	{
	        print "$key\t$csv{$key}\n";
	        print FH "$csv{$key}\n";
	}
	close FH;

	if (!-e $csvfile )
	{
		copy($TmpCsvFile,$csvfile) or die "Copy csvfile failed : $!\n";
		chmod 0775,$csvfile;
		unlink $TmpCsvFile;
		`cat $csvfile | mail -s "#MultiLiveLink# $csvfile missing" sen.b.yang\@alcatel-sbell.com.cn -c rnc-sh-pave-hawki\@LIST.ALCATEL-LUCENT.COM`; 
		return 1;
	}

	if(compare($TmpCsvFile,$csvfile)==0)
	{
		print "\nNo new XWO come in , Do nothing to $csvfile\n";
		unlink $TmpCsvFile;
		return 0;
	}
	else
	{
		my $change=`diff $csvfile $TmpCsvFile`;
		copy($TmpCsvFile,$csvfile) or die "Copy csvfile failed : $!\n";
	        chmod 0775,$csvfile;
	        unlink $TmpCsvFile;
		`echo $change  | mail -s "#MultiLiveLink# $csvfile changed" sen.b.yang\@alcatel-sbell.com.cn -c rnc-sh-pave-hawk\@LIST.ALCATEL-LUCENT.COM`;
	        return 1;
	}

}

sub getArrayfromHTMLfile
{
        #my $InputArray = $_[0];
        #my $FileName = $InputArray->[0];
	my $FileName = shift;
        if (! -e $FileName)
        {
                print "Error: htmlfile $FileName doesn't exist!\n";
                exit;
        }

        my @arr;
        open FH, "<", $FileName || die "Cannot read htmlfile:$!\n";
        while(<FH>)
        {
                next if ($_ !~ /DataStringToVariables/);
                if ( $_ =~ /\[(.*)\]/)
                {
                        @arr = split(/\},/,$1);
                }
                #grep "DataStringToVariables"  | awk -F "[" '{print $2}' | awk -F "]" '{print $1}'
        }
        close FH;

        return @arr;
}

sub GetFileIdFromWebpage
{
	my ($targetUrlId,$tname,$TmpHtmlFile)=@_;
        my $subpageId;
	system("curl -b $cookie -c $cookie -o $TmpHtmlFile -u $encoded --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$targetUrlId");
        my @array=&getArrayfromHTMLfile($TmpHtmlFile);
        print "\nWebPageId:",$targetUrlId,"\nName:$tname\nSize:",scalar(@array),"\n";

        my %FolderList=getFListfromArray("Folder",@array);
        my @FolderId= keys %FolderList;
        my %FileList=getFListfromArray("Document",@array);

        if (scalar(@FolderId)==0)
        {
                return %FileList;
        }
        else
        {	##search webpage recursively
                while($subpageId=pop @FolderId)
                {
                        my %subFileList=&GetFileIdFromWebpage($subpageId,$FolderList{$subpageId},$TmpHtmlFile);
                        foreach my $kk( keys %subFileList )
                        {
                                $FileList{$kk}=$subFileList{$kk};
			}
                }
        }
        return %FileList;
}

sub getFListfromArray
{
        my ($type,@arr)=@_;
        my %FList;
        foreach my $item (@arr)
        {
                next if ($item !~ /UA|RI|XWO/i); #condition
                next if ($item !~ /"typeName":"$type"/); #condition
		if ($item =~ /"dataId":"(\d+)".*"typeName":"(\w+)","name":"(.*)","link":"(.*)","size":"(\d+)%20(\w+)","date":"(.*)","dateReal"/)
                {
                        my $dataId=$1;
                        #my $typeName=$2;
                        my $name  =$3;
                        #my $size =$5." ".$6;
                        #my $date = $7;
                        #$date =~ s/%2F/\//g;$date =~ s/%20/ /g;$date =~ s/%3A/:/g;
                        $name =~ s/%2E/\./g; $name =~ s/%20/ /g; $name =~ s/%2D/-/g; $name =~ s/%28/(/g; $name =~ s/%2A/\*/g; $name =~ s/%29/)/g;
                        #print "name    :$name\n";
                        $FList{$dataId}=$name;
                }
        }
        return %FList;
}
