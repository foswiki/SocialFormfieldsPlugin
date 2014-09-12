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

package Foswiki::Plugins::SocialFormfieldsPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '0.01';
our $RELEASE = '0.01';
our $SHORTDESCRIPTION = 'Social formfield types for ratings and votings Foswiki';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub core {
  unless (defined $core) {
    require Foswiki::Plugins::SocialFormfieldsPlugin::Core;
    $core = new Foswiki::Plugins::SocialFormfieldsPlugin::Core();
  }
  return $core;
}


sub initPlugin {

  # TODO: 
  # * get my ratings
  
  return 1;
}

sub finishPlugin {
  return unless $core;
  $core->finish;
  undef $core;
}

sub beforeEditHandler {
  return core->beforeEditHandler(@_);
}

sub beforeSaveHandler {
  return core->beforeSaveHandler(@_);
}

1;
