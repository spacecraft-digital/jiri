A helpful assistant for Jadu/Spacecraft development. Integrates Jira, Gitlab, etc

Jiri is an internal tool, and is very much involved in everyday life on our Slack team.
However it should be considered a work in progress, so there may be a few rough edges here and there!

Features
--------
 - Each morning posts who is on holiday/working from home today to Slack
 - listens for when people mention Jira tickets, and unfurls them to give easy access
   to information and a link to the full ticket
 - Jiri also uses a MongoDB database to store information about customer projects,
   including URLs, server names, installed module versions, etc, etc.
   These data can be retrieved _and stored_ via the Slack chat interface, in natural language. e.g.
   - "@jiri what's the url for Oxford?"
   - "@jiri set oxford's dev server"
   - "@jiri add alias to oxford"
 - and many other things in various stages of development…!


Integrations
------------

 - People HR calendar feed: for holiday/leave information
 - Jira: information about issues/bugs, and easy searching, release tickets
 - Go Lives Smartsheet: for info about projects (go live dates and PM assignments)
 - Google Sheet: for info about projects
 - Gitlab: for merge requests and repo actions
 - MongoDB: Jiri never forgets
 - Salesforce*
 - Coffee machine*
 - Envoy*

*coming soon, perhaps

Design
------
Jiri is a Coffeescript app, communicating with Slack via a web socket.

Jiri's features are provided by modular Actions, which are each resonsible to
identify messages they understand, and do something with it.

It's easy to add an Action — it just needs `test` and `respondTo` methods.
If `test` returns true, that action is given the message to respond to, and Jiri
stops looking for any additional actions.

Jiri has a mechanism for statefulness, per-Slack-channel. This allows for things like:
- Matt: “Jiri, what's Oxfrd's URL?”
- Jiri: “Did you mean _Oxford's_ URL?”
- Matt: "Yes"
- Jiri: ”Oxford's production URL is https://www. …”

and avoiding spamming channels by unfurling Jira tickets only once within a certain time period.

Author
------
Written by Matt Dolan [@_MattDolan](https://twitter.com/_MattDolan)
