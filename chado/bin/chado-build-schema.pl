#!/usr/bin/perl -w

use strict;
use Data::Stag;
use FileHandle;
use Tk;

while ($ARGV[0] =~ /^\-/) {
    my $switch = shift @ARGV;
    if ($switch eq '-h' || $switch eq '--help') {
        print usage();
        exit 0;
    }
}

my $metafile = shift @ARGV;
my $SCHEMA_FILE = "chado_schema.sql";

$metafile = "chado-module-metadata.xml" unless $metafile;

my $schema_md = Data::Stag->parse($metafile);

my $module_dir = $schema_md->get('modules/source/@/path');
my @modules = $schema_md->get('modules/module');
my @components = $schema_md->get('modules/module/component');
my %module_h = map {$_->sget('@/id') => $_} (@modules, @components);
my @module_ids = map {$_->sget('@/id')} @modules;

# Tk - root frame
my $mw = MainWindow->new;
$mw->title("Chado Admin Tool");
my $mframe = $mw->Frame;

my $row = 0;
my %button_h = ();
foreach my $id (@module_ids) {
    my $mod = $module_h{$id};
    attach_module_checkbutton($id);

    # components associated with this module
    my @components = $mod->get('component');
    foreach my $component (@components) {
        my $c_id = $component->sget('@/id');
        attach_module_checkbutton($c_id, 1);
    }

}
$mframe->Button(-text=>"Create Schema",
                -command=>\&create_schema)->grid;
$mframe->pack(-side=>'bottom');
MainLoop;

exit 0;
#

sub attach_module_checkbutton {
    my $id = shift;
    my $indent = shift || 0;
    $row++;

    my $mod = $module_h{$id};
    my $desc = $mod->sget('description');
    my $status = $mod->sget('status');
    my $is_required = $mod->sget('@/required') ? 1 : 0;

    # button frame: contains button and help ? button
    my $bframe = $mframe->Frame;
    {
        $bframe->Label(-text=>".." x $indent)->pack(-anchor=>'w',-side=>'left')
          if $indent;
        
        my $text = $id;
        my $cb = $bframe->Checkbutton(-text=>$text,
                                      -command=>sub {
                                          module_checkbox_action($id);
                                      });
        $cb->{'Value'} = $is_required;
        $cb->pack(-anchor=>'w',-side=>'left',-fill=>'x',-padx=>0);
        $button_h{$id} = $cb;
    }
    my $col = 0;
    $bframe->grid(-column=>$col++,-row=>$row,-sticky=>'w');

    $mframe->Label(-text=>substr($desc,0,40))->grid(-column=>$col++,-row=>$row,-sticky=>'w');

    my $help_but =
      $mframe->Button(-text=>'?',
                      -foreground=>'red',
                      -command=>sub {
                          my $help_dialog = $mframe->messageBox(-message=>$mod->xml);
                          return;
                      });
    $help_but->grid(-column=>$col++,-row=>$row);

    if ($status) {
        $mframe->Label(-text=>$status->sget('@/code'),
                       -foreground=>'blue')->grid(-column=>$col,-row=>$row);
    }
    $col++;
}

sub module_checkbox_action {
    my $id = shift;
    my $mod = $module_h{$id};
    my $button = $button_h{$id};
    if ($button->{'Value'}) {
        # -- SELECT --
        my @dependencies = $mod->get('dependency/@/to');
        foreach my $dep_id (@dependencies) {
            my $b2 = $button_h{$dep_id};
            if (!$b2->{'Value'}) {
                $b2->select;
                # recursively set dependencies
                module_checkbox_action($dep_id);
            }
        }
    }
    else {
        # -- DESELECT --
        my @dependents = 
          map {
              $_->sget('@/id')
          } $schema_md->qmatch('module',
                               ('dependency/@/to'=>$id));
        foreach my $dep_id (@dependents) {
            my $b2 = $button_h{$dep_id};
            if ($b2->{'Value'}) {
                $b2->deselect;
                # recursively deselect dependents
                module_checkbox_action($dep_id);
            }
        }

        # deselect subcomponents
        my @components = $mod->get('component/@/id');
        foreach my $c_id (@components) {
            my $b2 = $button_h{$c_id};
            if ($b2->{'Value'}) {
                $b2->deselect;
                # recursively set dependencies
                module_checkbox_action($c_id);
            }
        }
    }
    return;
}

sub create_schema {
    my @sql_lines = ();
    foreach my $id (@module_ids) {
        my $mod = $module_h{$id};
        if ($button_h{$id}->{'Value'}) {
            push(@sql_lines, read_source($mod));
        }

        # components associated with this module
        my @components = $mod->get('component');
        foreach my $component (@components) {
            my $c_id = $component->sget('@/id');
            if ($button_h{$c_id}->{'Value'}) {
                push(@sql_lines, read_source($component));
            }
        
        }
        my $fh = FileHandle->new(">$SCHEMA_FILE");
        if ($fh) {
            print $fh join('',@sql_lines);
            $fh->close;
            #print `cat $SCHEMA_FILE`;
            $mw->messageBox(-message=>"schema created in file $SCHEMA_FILE");
        } else {
            $mw->messageBox(-message=>"cannot write to $SCHEMA_FILE");
        }
    }
}

sub read_source {
    my $mod = shift;
    my $id = $mod->sget('@/id');
    my @sources = $mod->get_source;
    my @lines = ();
    foreach my $source (@sources) {
        my $type = $source->sget('@/type');
        my $path = $source->sget('@/path');
        if ($type ne 'sql' && $type ne 'pgsql') {
            print STDERR "Skipping source $type $path for $id\n";
            next;
        }
        my $f = "$module_dir/$path";
        my $fh=FileHandle->new($f);        
        if ($fh) {
            push(@lines, <$fh>);
            $fh->close;
        }
        else {
            $mw->messageBox(-message=>"cannot find $f");
        }
    }
    return @lines;
}

sub usage {
    return <<EOM
chado-build-schema CHADO_METADATA_XML_FILE

Tk interface for generating a custome chado xml schema
;
EOM
}

# createdb DBNAME
# createlang plpgsql DBNAME