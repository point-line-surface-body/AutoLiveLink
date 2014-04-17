#!/usr/bin/env perl
#
# ASB *** Team
#
# ***@alcatel-sbell.com.cn
# ***@alcatel-sbell.com.cn
#
# 2012/9/25 Yang Sen C
# Note:  (1) init
#
#	
# 2012/10/7 Yang Sen C
# Note:  (1) study the curl/cookie of livelink
#	     (2) study the content of livelink webpage to extract files' ID/filename/time/downloadlink
#
# 2012/10/8 Yang Sen C
# Note:  (1) create cookie file
#	     (2) realize shell command to download files from livelink using the cookie file
#
#
# 2012/10/9 Yang Sen C
# Note:  (1) use perl to analyses the livelink webpage content to extract every file/folder's infomation and generate a csv recording file
#	     (2) coding the first version script to realize the basic automation grabing/parsering/analysesing/downloading operation
#
# 2012/10/11 Yang Sen C
# Note:  (1) automation script encountered error when user changed his password, it's due to the cookie file
#	     (2) fix method: generate new cookie file intime when automation script runs
#
# 2012/10/12 Yang Sen C
# Note:  (1) establish ctontab job on 135.251.224.225
#
#
# 2012/10/16 Yang Sen C
# Note:  (1) to run correctly, change $PATH to suite for more situation.
#
#
# 2012/10/17 Yang Sen C
# Note:  (1) move this AutoLiveLink.pl to /net/sbardy08/rnc_log/ACE/Hudson/hudsonJob
#	     (2) establish to Hudson http://rdrnagi.cn.alcatel-lucent.com:8080/view/Tools/job/AutoLiveLink/
#
#
# 2012/10/21 Yang Sen C
# Note:  (1) back up csv files
#
#
# 2012/11/17 Yang Sen C
# Note:  (1) sendEmail to ***@LIST.ALCATEL-LUCENT.COM when new Workorder downloaded
#
#

use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Compare;
use POSIX qw(strftime);
use MIME::Base64;
use Cwd;


#Time
my $starttime= strftime "%a %b %e %H:%M:%S %Y", localtime;

#local directory
my $XWODataPath="/net/sbardy08/rnc_log/ACE/XWODATA/";
my $cookiebackup=$XWODataPath."CookieStore/";
my $CSVStore=$XWODataPath."CSVStore/";
my $TmpHtmlFile=$XWODataPath."html.txt";
my $urlprefix="https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\?func=ll\&objId=";


my $encoded=decode_base64(decode_base64($ARGV[0]));
#my $user=$ARGV[0];#my $passwd=$ARGV[1];

#creat cookie
my $tstampforcookie=time();
my $tmpcookie=$XWODataPath.$tstampforcookie.".cookie";
my $url="https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe";


#ping
system("ping wcdma-ll.app.alcatel-lucent.com -c 2");

#system("touch $tmpcookie");
my $success=0;
if (CreateCookie($tmpcookie,$url)==0)
{
        print "Error when curl the webpage https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\n";
        unlink $tmpcookie;
	$success=1;
        exit 0;
}
else
{
	print "="x80,"\nCookie Info\nName:$tmpcookie\n\n";
}

#my $cookie=$PATH."cookie_file.txt";
my $cookie=$tmpcookie;
#my $cookie="cookie_file.txt";
system("cat",$cookie);
#csv mapping
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

#livelink webpage id
my %rnchash=(	'V71Global'=>57996986,
		'V81ATT'=>65897377,
		'V81Global'=>60998147,
		'V91ATT'=>65939307,
		'V91Global'=>65799582
		);

#ping
system("ping wcdma-ll.app.alcatel-lucent.com -c 2");


#foreach
foreach my $key (sort keys %rnchash)
{
	print "="x80,"\n\n";
	
	my $xwocsvpath=$XWODataPath.$key."/";
	my $csv=$xwocsvpath.$csvhash{$key};
	my $csvback=$CSVStore.$tstampforcookie.$csvhash{$key};	
	my $xwolist=$xwocsvpath."XwoList.csv";

	printf("%-14s:\t%s\n",$key,$rnchash{$key});
	my $currenturl=$urlprefix.$csvhash{$key};
	
#	`curl -b $cookie -c $cookie -o $TmpHtmlFile -u $user:$passwd --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\?func=ll\&objId=$csvhash{$key}`;
	#system("curl -b $cookie -c $cookie -o $TmpHtmlFile -u $user:$passwd --insecure -H \"Accept-Encoding:gzip,deflate\" $currenturl");
	#system("curl -b $cookie -c $cookie -o $TmpHtmlFile -u $user:xxx --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$csvhash{$key}");	
	copy($csv,$csvback);	
	my $change=ParserHTML($rnchash{$key},$csv,$TmpHtmlFile);
	unlink $csvback if ($change == 0);	

	my %list=GetFileIdFromWebpage($rnchash{$key},$key);
	open LIST,">",$xwolist || die "Cannot write to file $xwolist :$!\n";;
	print "="x80,"\n";
	#chdir($XWODataPath);
	foreach my $k (sort keys %list)
	{
	        next if ($list{$k} !~ /xwo$|gz$/i); #condition
		next if ($list{$k} !~ /^RNC/); #condition
        	print $k,"\t",$list{$k},"\n";
		print LIST "$k,$list{$k}\n";
		#download operation
		my $downdir="$XWODataPath$key";
		#print "downdir=$downdir\n";
		#print "****************",getcwd(),"**************\n";
		mkdir($downdir) if (! -d $downdir);
		my $targetfile="$downdir/$list{$k}";
		#next if (-e $targetfile);
		my $xwoname=$targetfile;
                if ($targetfile =~ /(.*\.xwo)\.gz$/i)
                {
                        $xwoname=$1;
                }
		if (-e $xwoname)
		{
			chmod 0775,$xwoname;
			next;
		}
		my $fileaddress="$urlprefix$k\&objAction=download";
		print "Downloading $targetfile :$fileaddress ......\n";
		system("curl -b $cookie -c $cookie -u $encoded --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$k\\&objAction=download -o $targetfile");
		`echo "$targetfile has been downloaded!"  | mail -s "#AutoLiveLink# $list{$k} is coming" sen.b.yang\@alcatel-sbell.com.cn -c rnc-sh-pave-hawk\@LIST.ALCATEL-LUCENT.COM`;
		system("gunzip","-f",$targetfile) if ( $targetfile =~ /\.gz$/);
		chmod 0775,$xwoname;		
	}
	close LIST;
}

#----------------------------------------------------
#               END & Compute time consumed
#----------------------------------------------------
sub END
{
&backup($cookie) if ($success == 0);
print "\n","-"x72,"\n";
print "Start:\t",$starttime,"\n";
my $end_time = strftime "%a %b %e %H:%M:%S %Y", localtime;
print "End  :\t",$end_time,"\n";
print "\n","-"x72,"\n";
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
        my $backup=$cookiebackup.$tstampforcookie.".cookie";
	print "\n\nCurrentcookie :$t_cookie\n";
	print "Backup cookie :$backup\n";
	copy($t_cookie,$backup);
	unlink $t_cookie;
}

#----------------------------------------------------
#               SubRoutine
#----------------------------------------------------
sub ParserHTML
{
	my ($pageid,$csvfile,$htmlfile)=@_;
	my $pageurl="$urlprefix$pageid";
	printf("%-14s:\t%s\n","URL",$pageurl);
	printf("%-14s:\t%s\n","CSV",$csvfile);
	print "="x80,"\n";
	
	system("curl -b $cookie -c $cookie -o $TmpHtmlFile -u $encoded --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$pageid");
	my @array;
	open FH, "<", $htmlfile || die "Cannot read file:$!\n";
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
		`cat $htmlfile`;
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
                if ($typeName =~ /Folder/i)
                {
                        #my $link="https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$dataId";
                        push @folderlist, $dataId;
                }
                if ($typeName =~ /Document/i)
                {
                        #my $link="https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$dataId";
                        push @filelist, $dataId;
                }

                #print "\n\n";
        }
}

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
	`cat $csvfile | mail -s "#AutoLiveLink# $csvfile missing" sen.b.yang\@alcatel-sbell.com.cn -c rnc-sh-pave-hawk\@LIST.ALCATEL-LUCENT.COM`; 
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
	`echo $change  | mail -s "#AutoLiveLink# $csvfile changed" sen.b.yang\@alcatel-sbell.com.cn -c rnc-sh-pave-hawk\@LIST.ALCATEL-LUCENT.COM`;
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
                        @arr = split /\},/,$1;
                }#grep "DataStringToVariables"  | awk -F "[" '{print $2}' | awk -F "]" '{print $1}'
        }
        close FH;

        return @arr;
}

sub GetFileIdFromWebpage
{
	my ($targetUrlId,$tname)=@_;
        my $subpageId;
	system("curl -b $cookie -c $cookie -o $TmpHtmlFile -u $encoded --insecure -H \"Accept-Encoding:gzip,deflate\" https://wcdma-ll.app.alcatel-lucent.com/livelink/livelink.exe\\?func=ll\\&objId=$targetUrlId");
        my @array=getArrayfromHTMLfile($TmpHtmlFile);
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
                        my %subFileList=&GetFileIdFromWebpage($subpageId,$FolderList{$subpageId});
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
