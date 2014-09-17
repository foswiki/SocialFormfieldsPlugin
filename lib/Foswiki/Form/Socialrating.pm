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

package Foswiki::Form::Socialrating;

use strict;
use warnings;
use Foswiki::Func ();
use Foswiki::Form::Rating ();
use Foswiki::Plugins::SocialFormfieldsPlugin ();
use Assert;
use JSON ();

our @ISA = ('Foswiki::Form::Rating');

BEGIN {
  if ($Foswiki::cfg{UseLocale}) {
    require locale;
    import locale();
  }
}

sub new {
  my $class = shift;
  my $this = $class->SUPER::new(@_);

  return $this;
}

sub isSocial { return 1; }

sub core {
  my $this = shift;

  return Foswiki::Plugins::SocialFormfieldsPlugin->core();
}

sub json {
  my $this = shift;

  unless ($this->{_json}) {
    $this->{_json} = JSON->new();
  }

  return $this->{_json};
}


sub renderForDisplay {
  my ($this, $format, $value, $attrs) = @_;

  if (defined($value) && $value =~ /^social\-(.*)$/) {
  
    $format =~ s/\$value\(display\)/$this->renderDisplayValue($value)/ge;
    $format =~ s/\$value\(json\)/$this->renderJsonValue($value)/ge;
    $format =~ s/\$value\(list\)/$this->renderListValue($value)/ge;
    $format =~ s/\$value/$this->renderBestValue($value)/ge;
  }

  return $this->SUPER::renderForDisplay($format, $value, $attrs);
}

sub renderDisplayValue {
  my ( $this, $id ) = @_;

  $id =~ s/^social\-//;

  my ($intVal) = $this->core->getAverageVote($id);
  my $val = $this->core->convertIntToVal(undef, $this, $intVal);
  return $this->SUPER::renderDisplayValue($val);
}

sub renderBestValue {
  my ( $this, $id ) = @_;

  $id =~ s/^social\-//;

  return $this->core->getAverageVote($id);
}

sub renderJsonValue {
  my ($this, $id) = @_;

  $id =~ s/^social\-//;

  return $this->core->getDistVotesAsJSON($id) || '';
}

sub renderListValue {
  my ($this, $id) = @_;

  $id =~ s/^social\-//;

  my $dist = $this->core->getDistVotes($id);

  my @list = ();
  if ($dist) {
    foreach my $item (@$dist) {
      my ($key, $val) = @$item;
      push @list, "$key:$val";
    }
  };

  return join(", ", @list);
}

1;
