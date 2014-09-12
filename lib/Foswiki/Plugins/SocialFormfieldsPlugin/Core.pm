# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# SocialFormfieldsPlugin is Copyright (C) 2014 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::SocialFormfieldsPlugin::Core;

use strict;
use warnings;

use Foswiki::Func ();
use Foswiki::Form ();
use Foswiki::OopsException ();
use Error qw( :try );
use DBI ();
use Data::Dump qw(dump);
use JSON ();

use constant TRACE => 0; # toggle me

our @DEFAULT_COLORS = (
  '#7cb5ec', 
  '#434348', 
  '#90ed7d', 
  '#f7a35c', 
  '#8085e9', 
  '#f15c80', 
  '#e4d354',
  '#8085e8', 
  '#8d4653', 
  '#91e8e1'
);

our %SQL_TEMPLATES = (
  'select_vote_of_user' => <<'HERE',
      select strval, intval from %votesTable% where voting_id = ? and user = ?
HERE

  'select_avg_votes' => <<'HERE',
      select avg(intval), count(*) from %votesTable% where voting_id = ?
HERE

  'insert_vote' => <<'HERE',
      replace into %votesTable%
        (voting_id, user, strval, intval, time) values 
        (?, ?, ?, ?, ?)
HERE

  'select_dist_votes' => <<'HERE',
      select strval, count(*) as count 
        from %votesTable% 
        where voting_id = ? 
        group by strval
        order by strval
HERE

  'select_best_vote' => <<'HERE',
      select strval, intval, count(*) as count 
        from %votesTable%
        where voting_id = ?
        group by strval
        order by count desc
        limit 1
HERE

  'select_id_of_voting' => <<'HERE',
      select id from %idsTable% where web = ? and topic = ? and field = ?
HERE

  'insert_id' => <<'HERE',
      replace into %idsTable%
        (web, topic, field) values (?, ?, ?)
HERE

);

###############################################################################
# static
sub writeDebug {
  return unless TRACE;
  print STDERR "SocialFormfieldsPlugin::Core - $_[0]\n";
  #Foswiki::Func::writeDebug("SocialFormfieldsPlugin::Core - $_[0]");
}

###############################################################################
sub new {
  my $class = shift;

  my $colors = $Foswiki::cfg{SocialFormfieldsPlugin}{Colors} || '';
  $colors = [split(/\s*,\s*/, $colors)];
  $colors = \@DEFAULT_COLORS unless $colors && scalar(@$colors);

  my $this = bless({
      dsn => $Foswiki::cfg{SocialFormfieldsPlugin}{Database}{DSN} || 'dbi:SQLite:dbname=' . Foswiki::Func::getWorkArea('SocialFormfieldsPlugin') . '/social.db',
      username => $Foswiki::cfg{SocialFormfieldsPlugin}{Database}{UserName},
      password => $Foswiki::cfg{SocialFormfieldsPlugin}{Database}{Password},
      tablePrefix => $Foswiki::cfg{SocialFormfieldsPlugin}{Database}{TablePrefix} || 'foswiki_socialformfields_',
      colors => $colors,
      @_
    },
    $class
  );

  $this->{idsTable} = $this->{tablePrefix}.'ids';
  $this->{votesTable} = $this->{tablePrefix}.'votes';

  writeDebug("dsn=$this->{dsn}");

  return $this;
}

###############################################################################
sub finish {
  my $this = shift;

  if ($this->{sths}) {
    foreach my $sth (values %{$this->{sths}}) {
      $sth->finish;
    }
    $this->{sths} = undef;
  }

  $this->{dbh}->disconnect if defined $this->{dbh};
  $this->{dbh} = undef;
}

###############################################################################
sub getStatementHandler {
  my ($this, $id) = @_;

  my $sth = $this->{sths}{$id};

  unless (defined $sth) {

    my $statement = $SQL_TEMPLATES{$id};

    throw Error::Simple("unknown statement id '$id'") unless $statement;

    $statement =~ s/\%(votesTable|idsTable)\%/$this->{$1}/g;

    $this->initDatabase unless defined $this->{dbh};

    $sth = $this->{sths}{$id} = $this->{dbh}->prepare($statement);
  }

  return $sth;
}

###############################################################################
sub beforeEditHandler {
  my ($this, $text, $topic, $web, $meta) = @_;

  writeDebug("beforeEditHandler($web, $topic)");
  my $session = $Foswiki::Plugins::SESSION;
  unless ($meta) {
    $meta = new Foswiki::Meta($session, $web, $topic, $text);
    #writeDebug("creating a new meta object");
  }

  my @socialFields = $this->getSocialFormFields($meta);
  return unless @socialFields;

  $this->initDatabase;

  my $wikiName = Foswiki::Func::getWikiName();

  foreach my $fieldDef (@socialFields) {

    my $name = $fieldDef->{name};
    my $type = $fieldDef->{type};
    my $field = $meta->get('FIELD', $name);

    next unless $field;
    next unless $field->{value} =~ /^social\-(.*)$/; 

    my $id = $1;

    writeDebug("editing social formfield $name, type=$type, id=$id, wikiName=$wikiName");

    if ($type =~ /\bmulti\b/) {
      print STDERR "WARNING: multi not supported yet in social formfield '$name' of type '$type' in $web.$topic\n";
      next;
    }

    my ($strVal, $intVal) = $this->getVoteOfUser($id, $wikiName);

    # patch it in before the edit form is displayed
    #writeDebug("user value: $strVal/$intVal");

    $field->{value} = $strVal;
  }
}

###############################################################################
sub beforeSaveHandler {
  my ($this, $text, $topic, $web, $meta) = @_;

  writeDebug("beforeSaveHandler($web, $topic)");

  my $session = $Foswiki::Plugins::SESSION;
  unless ($meta) {
    $meta = new Foswiki::Meta($session, $web, $topic, $text);
    #writeDebug("creating a new meta object");
  }

  my @socialFields = $this->getSocialFormFields($meta);
  return unless @socialFields;

  $this->initDatabase;

  foreach my $fieldDef (@socialFields) {
    my $name = $fieldDef->{name};
    my $field = $meta->get('FIELD', $name);
    my $id = $this->store($meta, $fieldDef, $field->{value});
    $field->{value} = 'social-'.$id;
  }
}

###############################################################################
sub json {
  my $this = shift;

  unless ($this->{_json}) {
    $this->{_json} = JSON->new();
  }

  return $this->{_json};
}

###############################################################################
sub store {
  my ($this, $meta, $fieldDefOrName, $val) = @_;

  my $name;
  my $fieldDef;

  if (ref($fieldDefOrName)) {
    $fieldDef = $fieldDefOrName;
    $name = $fieldDef->{name};
  } else {
    $name = $fieldDefOrName;
    $fieldDef = $this->getFormfieldDefinition($meta, $name);
  }

  my $type = $fieldDef->{type};
  my $wikiName = Foswiki::Func::getWikiName();

  # DEBUG: generate more data
  if (0) {
    $wikiName .= int( rand(10000) ) + 1;
  }

  my $web = $meta->web;
  my $topic = $meta->topic;
  my $id = $this->getVoting($web, $topic, $name) || $this->setVoting($web, $topic, $name);
  my $strVal = $val;
  my $intVal;

  # rating
  if ($type =~ /rating/) {
    $intVal = $this->convertValToInt($meta, $fieldDef, $val);
  } 

  # select and radio
  elsif ($type =~ /select|radio/) {
    $intVal = 0; # TODO: implement select+values logic here
  }

  $this->setVoteOfUser($id, $wikiName, $strVal, $intVal);

  writeDebug("store(): field: $name, wikiName: $wikiName, user value: $val, id: $id");
  
  return $id;
}

###############################################################################
sub initDatabase {
  my $this = shift;

  unless (defined $this->{dbh}) {

    writeDebug("connect database");
    $this->{dbh} = DBI->connect(
      $this->{dsn},
      $this->{username},
      $this->{password},
      {
        PrintError => 0,
        RaiseError => 1,
        AutoCommit => 1,
        ShowErrorStatement => 1,
      }
    );

    throw Error::Simple("Can't open database $this->{dsn}: " . $DBI::errstr)
      unless defined $this->{dbh};

    try { 
      $this->{dbh}->do("select * from $this->{idsTable} limit 1");
    } otherwise {

      # ids table
      writeDebug("creating $this->{idsTable} database");

      $this->{dbh}->do(<<HERE);
      create table $this->{idsTable} (
        id integer primary key,
        web char(255),
        topic char(255),
        field char(255)
      )
HERE

      $this->{dbh}->do("create unique index $this->{idsTable}_index on $this->{idsTable} (web, topic, field)");

      # votes table 
      writeDebug("creating $this->{votesTable} database");

      $this->{dbh}->do(<<HERE);
      create table $this->{votesTable} (
        voting_id integer,
        user char(255),
        strval char(255),
        intval int,
        time int
      )
HERE

      $this->{dbh}->do("create unique index $this->{votesTable}_index on $this->{votesTable} (voting_id, user)");
    };
  }

  return $this->{dbh};
}

###############################################################################
sub getVoting {
  my ($this, $web, $topic, $field) = @_;

  my $sth = $this->getStatementHandler('select_id_of_voting');
  my ($id) = $this->{dbh}->selectrow_array($sth, undef, $web, $topic, $field);

  return $id; 
}

###############################################################################
sub setVoting {
  my ($this, $web, $topic, $field) = @_;

  my $sth = $this->getStatementHandler('insert_id');
  $sth->execute($web, $topic, $field);

  return $this->{dbh}->last_insert_id(undef, undef, undef, undef);
}

###############################################################################
sub getAverageVote {
  my ($this, $id) = @_;

  my $sth = $this->getStatementHandler('select_avg_votes');
  my ($intVal, $count) = $this->{dbh}->selectrow_array($sth, undef, $id);

  return ($intVal, $count); 
}

###############################################################################
# returns an array (strVal, intVal) where srtVal is the originally value selected by
# the user and intValue the integer representation
sub getVoteOfUser {
  my ($this, $id, $user) = @_;

  $user = Foswiki::Func::getWikiName() unless defined $user;
  my $sth = $this->getStatementHandler('select_vote_of_user');
  my ($strVal, $intVal) = $this->{dbh}->selectrow_array($sth, undef, $id, $user);

  return ($strVal, $intVal);
}

###############################################################################
sub setVoteOfUser {
  my ($this, $id, $user, $strVal, $intVal) = @_;

  my $sth = $this->getStatementHandler("insert_vote");

  $intVal = int($strVal) unless defined $intVal; # SMELL

  if (0) {
    $user .= time(); # for testing
  }

  $sth->execute($id, $user, $strVal, $intVal, time())
    or throw Error::Simple("Can't execute statement: " . $sth->errstr);
}

###############################################################################
sub getBestVote {
  my ($this, $id) = @_;

  my $sth = $this->getStatementHandler('select_best_vote');

  my ($strVal, $intVal, $count) = $this->{dbh}->selectrow_array($sth, undef, $id);

  return ($strVal, $intVal, $count);
}

###############################################################################
sub getDistVotes {
  my ($this, $id) = @_;

  my $sth = $this->getStatementHandler('select_dist_votes');
  
  $sth->execute($id);

  return $sth->fetchall_arrayref();
}

###############################################################################
sub getDistVotesAsJSON {
  my ($this, $id) = @_;

  return $this->json->encode($this->getDistVotes($id));
}

###############################################################################
sub getFormDefinition {
  my ($this, $meta) = @_;

  my $formName = $meta->getFormName();
  return unless $formName;

  my ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($meta->web, $formName);
  return unless Foswiki::Func::topicExists($theFormWeb, $theForm);

  my $formDef;
  try {
    my $session = $Foswiki::Plugins::SESSION;
    $formDef = new Foswiki::Form($session, $theFormWeb, $theForm);
  } catch Foswiki::OopsException with {
    my $e = shift;
    print STDERR "ERROR: can't read form definition $theForm in SocialFormfieldsPlugin::Core::beforeSaveHandler\n";
  };

  return $formDef;
}

###############################################################################
sub convertValToInt {
  my ($this, $meta, $fieldDefOrName, $val) = @_;

  #writeDebug("called convertValToInt($name, $val)");

  my $name;
  my $fieldDef;

  if (ref($fieldDefOrName)) {
    $fieldDef = $fieldDefOrName;
    $name = $fieldDef->{name};
  } else {
    $name = $fieldDefOrName;
    $fieldDef = $this->getFormfieldDefinition($meta, $name);
  }

  my $opts = $fieldDef->getOptions();

  #writeDebug("opts=@$opts");

  my $index = 1;
  foreach my $opt (@$opts) {
    return $index if $opt eq $val;
    $index++;
  }

  return 0;
}

###############################################################################
# convert an integer value coming from the DB into a numeric value
# to be used by the rating widget
sub convertIntToVal {
  my ($this, $meta, $fieldDefOrName, $int) = @_;

  my $name;
  my $fieldDef;

  if (ref($fieldDefOrName)) {
    $fieldDef = $fieldDefOrName;
    $name = $fieldDef->{name};
  } else {
    $name = $fieldDefOrName;
    $fieldDef = $this->getFormfieldDefinition($meta, $name);
  }

  #my ($package, undef, $line) = caller;
  #writeDebug("called convertIntToVal() by $package::$line");

  # get all possible values
  my $opts = $fieldDef->getOptions();

  # if it is a numeric value, then nothing is left to do
  return $int unless $opts;

  # TODO: process +value maps
  my $max = scalar(@$opts);
  return 0 unless $max;

  $int = int($int + 0.5)-1;
  $int = $max if $int >= $max;
  return 0 if $int < 0;

  writeDebug("getting $int: @$opts[$int]");

  return @$opts[$int]
}

###############################################################################
sub getFormfieldDefinition {
  my ($this, $meta, $name) = @_;

  my $formDef = $this->getFormDefinition($meta);
  return unless $formDef;

  foreach my $fieldDef (@{$formDef->getFields()}) {
    return $fieldDef if  $fieldDef->{name} eq $name;
  }

  return undef;
}

###############################################################################
sub getSocialFormFields {
  my ($this, $meta) = @_;

  my $formDef = $this->getFormDefinition($meta);
  return unless $formDef;

  my @fields = ();
  foreach my $fieldDef (@{$formDef->getFields()}) {
    push @fields, $fieldDef if $fieldDef->can("isSocial") && $fieldDef->isSocial();
  }

  return @fields;
}

1;
