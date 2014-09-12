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

package Foswiki::Form::SocialListFieldDefinition;

use strict;
use warnings;

use Foswiki::Plugins::SocialFormfieldsPlugin ();
use Foswiki::Form::ListFieldDefinition ();
use Foswiki::Func ();
use JSON ();
use Assert;

our @ISA = ('Foswiki::Form::ListFieldDefinition');

BEGIN {
  if ($Foswiki::cfg{UseLocale}) {
    require locale;
    import locale();
  }
}

sub new {
  my $class = shift;

  return $class->SUPER::new(@_);
}

sub isSocial { return 1; }

sub json {
  my $this = shift;

  unless ($this->{_json}) {
    $this->{_json} = JSON->new();
  }

  return $this->{_json};
}

sub core {
  my $this = shift;

  return Foswiki::Plugins::SocialFormfieldsPlugin->core();
}

sub colors {
  my $this = shift;

  return $this->core->{colors};
}

sub renderForDisplay {
  my ($this, $format, $value, $attrs) = @_;

  if ($value =~ /^social\-(.*)$/) {
  
    my $id = $1;
    my $displayValue = '';
    my $jsonValue = '';
    my $listValue = '';

    $displayValue = $this->getDisplayValue($value) || '' if $format =~ /\$value\(display\)/;
    $jsonValue = $this->core->getDistVotesAsJSON($id) || '' if $format =~ /\$value\(json\)/;
    $listValue = $this->getListValue($id) || '' if $format =~ /\$value\(list\)/;
    ($value) = $this->core->getBestVote($id) ;#if $format =~ /\$value(?:[^\(]|$)/;

    $format =~ s/\$value\(display\)/$displayValue/g;
    $format =~ s/\$value\(json\)/$jsonValue/g;
    $format =~ s/\$value\(list\)/$listValue/g;
    $format =~ s/\$value/$value/g;
  }

  return $this->SUPER::renderForDisplay($format, $value, $attrs);
}

sub getListValue {
  my ($this, $id) = @_;

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

sub getDisplayValue {
  my ($this, $value) = @_;

  my $result;

  if ($value =~ /^social\-(.*)$/) {
    my $id = $1;
    my $data = $this->core->getDistVotes($id);

    my $total = 0;

    foreach my $item (@$data) {
      my ($key, $val) = @$item;
      $total += $val;
    }

    $result = '<div class="foswikiSocialRating jqUITooltip" data-arrow="true" data-theme="info" data-position="top" data-delay="0">';

    my @colors = @{$this->colors};
    my $numColors = scalar(@colors);
    my $i = 0;
    foreach my $item (@$data) {
      my ($key, $val) = @$item;
      my $color = $colors[$i % $numColors];
      $result .= "<div class='foswikiSocialRatingValue' title='$key' style='float:left;width:" . ($val / $total * 100) . "%;background-color:$color'>&nbsp;</div>";
      $i++;
    }

    $result .= '%CLEAR%</div>';
  } else {
    $result = $this->SUPER::getDisplayValue($value);
  }

  return $result;
}

1;

