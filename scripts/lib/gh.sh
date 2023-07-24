# Lib with GitHub specific utilities

# installAndSetUpGitHubCli method installs and sets up the GitHub CLI (gh)
#
# Parameters:
#     1. GH Token ENV variable name (optional): Because gh needs to unset the variable where we set the GitHub Token,
#         we need to provide the NAME of the variable, not the variable itself.
#         By default it will use GH_TOKEN
function installAndSetUpGitHubCli() {
    sudo snap install gh --edge

    local ghTokenEnvVarName=${1:-"GH_TOKEN"}

    echo ${!ghTokenEnvVarName} > .gh_token
    unset $ghTokenEnvVarName
    gh auth login --with-token < .gh_token
}

# getSfdxTestConfig function gets the body of the pull request passed as an argument and parses it
#     to find out if we should run specified tests or no tests at all.
#
#     This function returns the arguments we can pass to sfdx force:source:deploy or sfdx force:mdapi:deploy to define what to test.
#
#     In order to specify a list of tests we need to write the list of test class names between [CI_TESTS] and [/CI_TESTS],
#     one test class name per line, i.e.
#     [CI_TESTS]
#     Test1
#     Test2
#     Test3
#     [/CI_TESTS]
#
#     If we don't want to run tests for this PR, we should add a line with this tag: [NO_CI_TESTS]
#
#     In case getSfdxTestConfig doesn't find either a list of tests or the [NO_CI_TESTS] tag,
#     it will return the arguments to RunLocalTests
function getSfdxTestConfig() {
    local travisPullRequest=$1
    local sfdxMode=$2

    local PR_BODY=$(gh pr view $travisPullRequest --json body --jq .body)
    local SFDX_TEST_CONFIG=$(node ./scripts/getTestConfigForSfdx.js "$PR_BODY" $sfdxMode)

    echo $SFDX_TEST_CONFIG
}