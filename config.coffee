
# Config — defaults can be overridden with environment vars

config =
    slack_apiToken: process.env.SLACK_API_TOKEN
    slack_autoReconnect: true
    slack_autoMark: true

    # a list of Slack channels that aren't customer channels, so shouldn't be used as a value of Reporting Customer
    slack_nonCustomerChannels: 'academy accessibility accreditations administration agile astronauts betterconnected boilerplate-redux branding buildtaskrefine business-models buzz cambs_xfp_testing cio-summit-app cio-team-jaam civica cmp cms-changes cms-docs cms-suggestion cmserrors cod-reviews code-conventions code-reviews code-spacecraft comets comets-deployments community-videos conferences control-centre-ui custom-devs customer-build-jobs demo-sites deployments design-critique disruptive docker dot-net engineering equipment eye-tracking feature-requests films-tv finance football gaming general global-partners google-certification googleplus gravity happiness hydrazine hydrazine-test ideabox innovationday innovations jadu-change-freeze jadu-north javascript jokes lostlinks marketing meteordeployments movers_shakers movetophp56 neutron nudge nudgenudge online-tutorials openstack-migrate openstack-weirdness optimus orbit-and-twig peoplehr perceptive planning-portal product-content project-managers projects pulsar quality quantum quantum-cantina quantum-dev-errors quantum-errors quantum-live-errors quantum-notifications quantum-uat-errors quasar quotes random rant recruitment redirects releasetools scripttesting scrum-masters security slack-meta social spacecraft spacecraft-deploy spacecraft-tickets spacejam spam spotify sqwiggle ssl starwars stellar sumpy support support-jira-status svn-to-git syadmins sysadmins testing testing-tests tombottest tommys-channel transport twig un-hack-a-thon-deux uncompany upgrades ux vpn wayofjadu weareallsales webdev weejot worldcupsweeptake xfp-changes zody_ac-forms'

    slack_botsToIgnore: 'GitLab gitlab Jenkins HeyUpdate JIRA Hydrazine'

    # users / channels to notify of app events such as start up and restart
    slack_processAlerts: [
        '#jiri-status'
    ]

    memcached_hosts: [
        '127.0.0.1'
    ]

    jira_user: process.env.JIRA_USER
    jira_password: process.env.JIRA_PASSWORD

    gitlab_url: 'https://gitlab.hq.jadu.net/'
    gitlab_token: process.env.GITLAB_TOKEN

    mongo_url: 'mongodb://localhost/crater'

    isoSpreadsheetId: '0AhQfpyH66MJXdGpYcGZiMTNDaFQ0dGpJcnJqZXdnaXc'
    google_client_id: process.env.GOOGLE_CLIENT_ID
    google_client_email: process.env.GOOGLE_CLIENT_EMAIL
    google_private_key: process.env.GOOGLE_PRIVATE_KEY

    peopleCalendarUrl: process.env.PEOPLE_CALENDAR_URL

    sshUser: 'root'
    sshPrivateKeyPath: '/root/.ssh/jadu_webdev_key'

    giphy_api_key: 'dc6zaTOxFJmzC'

    git_repos_folder: '/tmp/jiri-repos'

    timezone: 'Europe/London'

    bot_name: 'Jiri'
    bot_iconUrl: 'http://res.cloudinary.com/jadu-slack/image/upload/v1434266028/jiri-icon_gmhsch.png'

    supportUrl: 'https://support.jadu.net/jadu/support/support_ticket_list.php?subject=#{ref}'

    cxm_api_url: 'https://jadusupport.api.q.jadu.net/api/service-api/jiri'
    cxm_api_key: process.env.CXM_API_KEY
    cxm_caseUrl: 'https://jadusupport.q.jadu.net/q/case/#{reference}/timeline'

    calendarChannel: '#general'

    # the number of seconds to ignore a Jira ref for after it is once unurled
    timeBeforeRepeatUnfurl: 1800

    # passed to inflect.inflections
    inflections:
        # specify singular words for the given aliases
        singular:
            'alias': 'alias'
            'aliases': 'alias'

# Show a message if secrets haven't been set in the environment
(require './src/utils/assert_config_secrets') config

# Mix in dev config
if '--debug' in process.argv
    devConfig = require './config-dev'
    config[key] = value for own key, value of devConfig

module.exports = config
