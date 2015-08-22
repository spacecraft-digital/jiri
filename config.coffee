
# Config — defaults can be overridden with environment vars

config =
    slack_apiToken: process.env.SLACK_API_TOKEN
    slack_autoReconnect: true
    slack_autoMark: true

    # a list of Slack channels that aren't customer channels, so shouldn't be used as a value of Reporting Customer
    slack_nonCustomerChannels: 'academy accessibility accreditations administration agile astronauts betterconnected boilerplate-redux branding buildtaskrefine business-models buzz cambs_xfp_testing cio-summit-app cio-team-jaam civica cmp cms-changes cms-docs cms-suggestion cmserrors cod-reviews code-conventions code-reviews code-spacecraft comets comets-deployments community-videos conferences control-centre-ui custom-devs customer-build-jobs demo-sites deployments design-critique disruptive docker dot-net engineering equipment eye-tracking feature-requests films-tv finance football gaming general global-partners google-certification googleplus gravity happiness hydrazine hydrazine-test ideabox innovationday innovations jadu-change-freeze jadu-north javascript jokes lostlinks marketing meteordeployments movers_shakers movetophp56 neutron nudge nudgenudge online-tutorials openstack-migrate openstack-weirdness optimus orbit-and-twig peoplehr perceptive planning-portal product-content project-managers projects pulsar quality quantum quantum-cantina quantum-dev-errors quantum-errors quantum-live-errors quantum-notifications quantum-uat-errors quasar quotes random rant recruitment redirects releasetools scripttesting scrum-masters security slack-meta social spacecraft spacecraft-deploy spacecraft-tickets spacejam spam spotify sqwiggle ssl starwars stellar sumpy support support-jira-status svn-to-git syadmins sysadmins testing testing-tests tombottest tommys-channel transport twig un-hack-a-thon-deux uncompany upgrades ux vpn wayofjadu weareallsales webdev weejot worldcupsweeptake xfp-changes zody_ac-forms'

    # URL to user profile
    debugSlackUserId: 'U025466D6'

    jira_protocol: 'https'
    jira_host: 'jadultd.atlassian.net'
    jira_port: '443'
    jira_user: 'jadu_support'
    jira_password: process.env.JIRA_PASSWORD
    jira_issueUrl: 'https://jadultd.atlassian.net/browse/#{key}'

    jira_status_inProgress: ['In Progress', 'WebDev in Progress', 'UX in Progress']
    jira_status_toTest: 'Testing ToDo: Spacecraft'
    jira_status_webdevToDo: 'WebDev ToDo'
    jira_status_uxToDo: 'UX ToDo'
    jira_status_awaitingReview: ['Code Review ToDo']
    jira_status_awaitingMerge: ['Awaiting Merge', 'Awaiting Merge: Spacecraft']
    jira_status_readyToRelease: 'Ready for Release: Spacecraft'

    gitlab_url: 'https://gitlab.hq.jadu.net/'
    gitlab_token: process.env.GITLAB_TOKEN

    peopleCalendarUrl: process.env.PEOPLE_CALENDAR_URL

    bot_name: 'Jiri'
    bot_iconUrl: 'http://res.cloudinary.com/jadu-slack/image/upload/v1434266028/jiri-icon_gmhsch.png'

    supportUrl: 'https://support.jadu.net/jadu/support/support_ticket_list.php?subject=#{ref}'

    calendarChannel: '#scripttesting'

    # the number of seconds to ignore a Jira ref for after it is once unurled
    timeBeforeRepeatUnfurl: 120

# Mix in dev config
if '--debug' in process.argv
    devConfig = require './config-dev'
    config[key] = value for own key, value of devConfig

# Assert some required config
throw "SLACK_API_TOKEN needs to be set in the environment" unless config.slack_apiToken?
throw "JIRA_PASSWORD needs to be set in the environment" unless config.jira_password?
throw "GITLAB_TOKEN needs to be set in the environment" unless config.gitlab_token?
throw "PEOPLE_CALENDAR_URL needs to be set in the environment" unless config.peopleCalendarUrl?

module.exports = config
