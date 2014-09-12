# ---+ Extensions
# ---++ SocialFormfieldsPlugin
# This is the configuration used by the <b>SocialFormfieldsPlugin</b>.

# **STRING**
# <h3>Setup databases connections</h3>
# Configuration info for the database to be used to store ratings.
$Foswiki::cfg{SocialFormfieldsPlugin}{Database}{DSN} = 'dbi:SQLite:dbname=$Foswiki::cfg{WorkingDir}/work_areas/SocialFormfieldsPlugin/social.db';

# **STRING 80 **
# Prefix used naming tables and indexes generated in the database.
$Foswiki::cfg{SocialFormfieldsPlugin}{Database}{TablePrefix} = 'foswiki_socialformfields_';

# **STRING 80 **
# Username to access the database
$Foswiki::cfg{SocialFormfieldsPlugin}{Database}{UserName} = '';

# **PASSWORD 80 **
# Credentials for the user accessing the database
$Foswiki::cfg{SocialFormfieldsPlugin}{Database}{Password} = '';

1;
