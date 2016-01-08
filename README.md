A helpful assistant for Jadu/Spacecraft development. Integrates Jira, Gitlab, etc

Jiri is an internal tool, and is very much involved in everyday life on our Slack team.
However it should be considered a work in progress, so there may be a few rough edges here and there!

Features
--------
 - Each morning posts who is on holiday/working from home today to Slack
 - listens for when people mention Jira tickets, and unfurls them to give easy access
   to information and a link to the full ticket
 - provides information from its
 - Jiri also uses a MongoDB database to store information about customer projects,
   including URLs, server names, installed module versions, etc, etc.
   These data can be retrieved _and stored_ via the Slack chat interface, in natural language.
   e.g. "@jiri what's the url for Oxford?",
   "@jiri set oxford's dev server"
   "@jiri add alias to oxford"


Integrations
------------

### Read only
 - People HR calendar feed: for holiday/leave information
 - Go Lives Smartsheet: for info about projects (go live dates and PM assignments)
 - ISO Spreadsheet: for info about projects

 - Jira: for bugs/issues
 - Gitlab: for merge requests and repo actions

Author
------
Written by Matt Dolan
Twitter: @_MattDolan
