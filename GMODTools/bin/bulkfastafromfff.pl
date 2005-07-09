#!/usr/bin/perl
# bulkfastafromfff.pl
# quick test to generate fasta from input fff features
# including intergene region extraction.
# d.gilbert, aug04

use Bio::GMOD::Bulkfiles;    
use Getopt::Long;    

use vars qw/@infile $between $debug $config $format/;
use vars qw/$lastchr $lastfff $ffformat/;
my $featset= 'any'; ##.. FIXME
my $intergenetype='intergene';
my $chr= undef;
my $outname = "bulk.fasta";

my $ok= Getopt::Long::GetOptions( 
'config=s' => \$config,
'input=s' => \@infile,  
'output=s' => \$outname,
'chr=s' => \$chr,
'between' => \$intergene,
'debug=s' => \$debug,
);


die <<"USAGE" unless ($ok && $config && @infile);
Generate fasta from input feature lines in fff format,
including option for inter-gene regions.
usage: $0 
  -config=bulkfile-config 
    Bio::GMOD::Bulkfiles config file pointing to genome data files
  -input=fff-feature-file(s) 
    FFF feature file ('stdin' is ok) 
  -outfile=bulk.fasta
  -chr=2L   
    chr name is used to find chromsome dna file
    if only 1 input fff file, can give chromosome name,
    otherwise need to find chr in fff files
  -between
     extract sequence between last-gene:next-gene location
     (any feature types ok, intergenic regions most interesting)
      
FFF lines look like this (generated by Bio::GMOD::Bulkfiles along with gff)
# Feature  name    cytomap     location       id      db_xref    notes
source     dmel    2h          1..1694121
gene       Rab21   20A4-20A5-h26   complement(350166..351284)      CG17515

USAGE


my $sequtil= Bio::GMOD::Bulkfiles->new( 
  configfile => $config, 
  debug => $debug, showconfig => 0,
  );

open(FA,">$outname") or die "$outname";
my $fah= *FA;


my $n= 0;
foreach my $inf (@infile) 
{
  my $inh;
  if ($inf eq '-' || lc($inf) eq 'stdin') { $inh= *STDIN; }
  else { open(IN,$inf); $inh= *IN; }
  warn "reading $inf\n" if $debug;
  ($lastchr,$lastfff)=(undef,undef);
  while (<$inh>) {
    unless($chr) {
      if (/^# source:\s+(\S+)/) { $chr=$1; }  # comment line
      elsif (/\bsource\s(\S+)\s(\S+)/) {  $chr= $2; }   # should be top feature line
      elsif (/^(\w\S+)\s([\d\-]+)\s(\w+)/) {  $chr= $1; } # version w/ leading chr
      }
    next unless(/^\w/); chomp;
    
    my $fff= $_;
    my $fffout= $fff;
    
    my ($type,$name,$cytomap,$baseloc,$id,$dbxref,$notes);
    ( $type, $name,$cytomap,$baseloc,$id,$dbxref,$notes,$chr)
        = $sequtil->splitFFF( $fff,$chr); #? only to check $chr changes
    
    # for intergene regions - invert last-gene:next-gene location
    ## $fff= intergeneFromGeneFFF($chr,$fff) if ($between);
    if ($between) {
      if($lastchr eq $chr && $lastfff) {
        $fffout= $sequtil->intergeneFromFFF2($chr, $lastfff, $fff);
        }
      }
    ($lastchr,$lastfff)=($chr,$fff);
    if($fffout){
      my $fasta= $sequtil->fastaFromFFF( $fffout, $chr, $featset);
      if ($fasta) { print $fah $fasta; $n++; }
      else { warn "no fasta for $chr: $_\n"; }
      }
    }
  close($inh);
  $chr= undef;
}
close($fah); 
print STDERR "done - wrote $n fasta entries to $outname\n";
exit;


## add to Bulkfiles.pm
# sub intergeneFromFFF2
# {
#   my($chr,$fff1,$fff2)= @_;
#   my $newfff='';
#   my ($type,$name,$cytomap,$baseloc,$id,$dbxref,$notes);
#   my ($chr2,$name2,$baseloc2,$id2);
#   
#   ($chr, $type,$name,$cytomap,$baseloc,$id,$dbxref,$notes)
#       = splitFFF($chr, $fff1);
#   my($start,$stop,$strand)= $sequtil->maxrange($baseloc);
#   
#   ($chr2, $type,$name2,$cytomap,$baseloc2,$id2,$dbxref,$notes)
#       = splitFFF($chr, $fff2);
#   my($start2,$stop2,$strand2)= $sequtil->maxrange($baseloc2);
#   
#   if ($chr eq $chr2 && $stop < $start2) { 
#     my $iname= "$name/$name2";
#     my $iid= "$id/$id2";
#     my $interloc= ($stop+1)."..".($start2-1);
#     $newfff= join("\t", $intergenetype, $iname,'-', $interloc, $iid,);
#     }
#   return $newfff;
# }


## add to Bulkfiles.pm
# sub splitFFF
# {
#   my(  $fffeature, $chr)= @_;
#   my($type,$name,$cytomap,$baseloc,$id,$dbxref,$notes);
#   chomp($fffeature);
#   my @v= split "\t", $fffeature;
#   foreach (@v) { $_='' if $_ eq '-'; }
#   
#   my $ffformat = 0; #? test always
#   if ( @v > 7 || ($v[0] =~ /^\w/ && $v[1] =~ /^\d+$/)) { $ffformat= 2; }  
#   else { $ffformat= 1; }  
#   if ($ffformat == 1) { ($type,$name,$cytomap,$baseloc,$id,$dbxref,$notes)= @v; }
#   elsif ($ffformat == 2) { ($chr,$bstart,$type,$name,$cytomap,$baseloc,$id,$dbxref,$notes)= @v; }
#   return ($type,$name,$cytomap,$baseloc,$id,$dbxref,$notes,$chr);
# }
