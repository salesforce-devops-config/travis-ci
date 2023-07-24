source ./scripts/lib/sfdc.sh

# deployDeltaPackage will deploy or validate a delta package.
#
# Parameters:
#     1. SFDC Auth URL: the force://... url (we can get it with sfdx force:org:display --verbose -u <org alias>)
#     2. commitRange: This is the git commit range using the following format "<to_commit>...<from_commit>" or a single commit.
#         In case we get a single commit or a tag or a branch name, it will use it as <from_commit> and HEAD as <to_commit>.
#         I.e. In Travis-CI we could pass $TRAVIS_COMMIT_RANGE or $TRAVIS_TAG
#     3. Only Check (optional): it's a flag (true or false) used to decided if it will deploy or only check the deployment.
#         By default it's "false" so it will deploy.
#         In order to only validate, we need to pass "true" to this parameter (any other value than "false" will only validate)
#     4. Use Default Test Level (optional): it's a flag (true or false) used to decided if it will use the org's default
#           test level on deployments or it will run the tests defined in the test/ directory when it's a
#           deployment (Only Check flag is "false").
#         By default it's "true" so it will use the default test level for the org.
#         In order to run deploy using the test levels in "test/" directory we need to pass "false".
#
# Dependencies:
#     - @salesforce/cli: This method needs to have sf installed in the server
#         We can install it by running "npm install @salesforce/cli --global" on before_install
#     - sfdx-git-delta plugin: This method requires us to have sfdx-git-delta installed
#         We can install it by running "yes | sf plugins install sfdx-git-delta" on before_install
function deployDeltaPackage() {
    if [ $# -lt 2 ]; then
        echo "Usage: deployDeltaPackage <SFDC Auth URL> <commit range | commit> [<only check> [<use default test level>]]"
        return -1
    fi

    local sfdcAuthUrl=$1
    local commitRange=$2
    local onlyCheck=${3:-"false"}
    local useDefaultTestLevel=${4:-"true"}

    authenticateSfdxOrg sfdxurl $sfdcAuthUrl sfdcOrg
    createDeltaPackage ./delta $commitRange

    local testConfig=""

    if [ -n "$TRAVIS_PULL_REQUEST" ]; then
        source ./scripts/lib/gh.sh
        installAndSetUpGitHubCli "GH_TOKEN"
        testParams=$(getSfdxTestConfig $TRAVIS_PULL_REQUEST)
    fi
    
    if [ -z "$testConfig" ]; then
        testConfig=$(getTestConfig)
    fi

    local onlyCheckConfig=""
    local action="Deploying"
    if [[ "${onlyCheck,,}" != "false" ]]; then
        action="Validating deployment"
        onlyCheckConfig="--dry-run"
    elif [[ "${useDefaultTestLevel,,}" == "true" ]]; then
        # It's a promotion but we want to run it using the default test level, so we clear testConfig variable
        testConfig=""
    fi

    echo "$action delta package"
    if [[ -d ./delta/package ]]; then
        echo "sf project deploy start ${onlyCheckConfig} -o sfdcOrg -x ./delta/package/package.xml
            --post-destructive-changes ./delta/destructiveChanges/destructiveChanges.xml
            --ignore-warnings --ignore-conflicts --verbose ${testConfig}"
        sf project deploy start ${onlyCheckConfig} -o sfdcOrg -x ./delta/package/package.xml \
            --post-destructive-changes ./delta/destructiveChanges/destructiveChanges.xml \
            --ignore-warnings --ignore-conflicts --verbose ${testConfig}
    else
        echo "$action: not needed, no metadata in the delta package..."
    fi
}

# runDeltaPMD downloads and installs PMD (6.50.0) and runs it on a delta package with the changes between
#     two given commits.
#
# Parameters:
#     1. commitRange: This is the git commit range using the following format "<to_commit>...<from_commit>" or a single commit.
#         In case we get a single commit or a tag or a branch name, it will use it as <from_commit> and HEAD as <to_commit>.
#         I.e. In Travis-CI we could pass $TRAVIS_COMMIT_RANGE or $TRAVIS_TAG
#     2. apex ruleset path (optional): the path for PMD's Apex ruleset. The default value is "rulesets/apex_ruleset.xml"
#
# Dependencies:
#     - @salesforce/cli: This method needs to have sf installed in the server
#         We can install it by running "npm install @salesforce/cli --global" on before_install
#     - sfdx-git-delta plugin: This method requires us to have sfdx-git-delta installed
#         We can install it by running "yes | sf plugins install sfdx-git-delta" on before_install
function runDeltaPMD() {
    if [ $# -lt 1 ]; then
        echo "Usage: runDeltaPMD <commit range | commit> [<apex ruleset path>]"
        return -1
    fi
    
    wget https://github.com/pmd/pmd/releases/download/pmd_releases%2F6.50.0/pmd-bin-6.50.0.zip
    unzip pmd-bin-6.50.0.zip

    local commitRange=$1
    local apexRuleSet=${2:-"rulesets/apex_ruleset.xml"}
    
    createDeltaPackage ./delta $commitRange
    ./pmd-bin-6.50.0/bin/run.sh pmd -d delta/**/classes -R $apexRuleSet -f textcolor --verbose
}

# runDeltaPrettier verifies the delta package with prettier
#
# Parameters:
#     1. commitRange: This is the git commit range using the following format "<to_commit>...<from_commit>" or a single commit.
#         In case we get a single commit or a tag or a branch name, it will use it as <from_commit> and HEAD as <to_commit>.
#         I.e. In Travis-CI we could pass $TRAVIS_COMMIT_RANGE or $TRAVIS_TAG
#
# Dependencies:
#     - @salesforce/cli: This method needs to have sf installed in the server
#         We can installing by running "npm install @salesforce/cli --global"
#     - sfdx-git-delta pluging: This method requires us to have sfdx-git-delta installed
#         We can install it by running "yes | sf plugins install sfdx-git-delta"
#     - include "prettier" and "prettier-plugin-apex" to package.json as a dependence
#     - have a ".prettierrc.yaml" that overrides .html files on lwc, components, etc...
function runDeltaPrettier() {
    if [ $# -lt 1 ]; then
        echo "Usage: runDeltaPrettier <commit range | commit>"
        return -1
    fi

    local commitRange=$1

    createDeltaPackage ./delta $commitRange
    extensions=("*.cls" "*.cmp" "*.component" "*.css" "*.html" "*.js" "*.page" "*.trigger")
    for extension in ${extensions[@]}; do
        echo "Looking for $extension files on ./delta"
        find ./delta -name $extension >> found_files
        files_size=$(stat -c%s found_files)
        if [[ $files_size > 0 ]]; then
            echo "$extension files found on ./delta"
            break
        fi
    done

    files_size=$(stat -c%s found_files)
    echo "found_files size > ${files_size}"
    if [[ $files_size > 0 ]]; then
        prettier --loglevel warn --ignore-unknown --check "delta/**/*"
    else
        echo "No need to run prettier..."
    fi
}

# createGitHubRelease creates a GitHub release with a zip file including the changes between the two given version TRAVIS_TAG
#
# Parameters:
#     1. previous version: git tag of the previous version (ideally the current version in production)
#     2. new version: git tag of the next version we will deploy/validates
#
# Dependencies:
#     - @salesforce/cli: This method needs to have sf installed in the server
#         We can install it by running "npm install @salesforce/cli --global" on before_install
#     - sfdx-git-delta pluging: This method requires us to have sfdx-git-delta installed
#         We can install it by running "yes | sf plugins install sfdx-git-delta" on before_install
#     - Needs to have a GitHub personal access token in the environment variable "GH_TOKEN"
function createGitHubRelease() {
    if [ $# -lt 2 ]; then
        echo "Usage: createGitHubRelease <previous version> <new version>"
        return -1
    fi
    
    prevVersion=$1
    newVersionTag=$2

    source ./scripts/lib/gh.sh
    installAndSetUpGitHubCli "GH_TOKEN"

    createDeltaPackage ./delta $prevVersion
    cd ./delta
    echo "Zipping the delta package"
    zip -r ${newVersionTag}.zip .
    echo "gh release create ${newVersionTag} ${newVersionTag}.zip
    --title \"Release ${newVersionTag}\"
    --notes \"This release includes the changes between the versions ${prevVersion} and ${newVersionTag}\""
    gh release create ${newVersionTag} ${newVersionTag}.zip \
        --title "Release ${newVersionTag}" \
        --notes "This release includes the changes between the versions ${prevVersion} and ${newVersionTag}"
}

# runTests runs tests on a given salesforce org
# 
# Parameters:
#     1. SFDC Auth URL: the force://... url (we can get it with sfdx force:org:display --verbose -u <org alias>)
#     2. test config (optional): It accepts the following values:
#         - default: it will run the default set of tests of the org type
#         - all: it will run all tests in an org
#         - local: it will run all local tests
#         - from-pr: when we use runTests on pull_request trigger, it will get the test config from the body of the PR
#         - from-env-var: it will use the environment variable CI_RUN_TESTS_CONFIG as test config.
#             I.e. We can configure CI_RUN_TESTS_CONFIG = "--testlevel RunSpecifiedTests --classnames TestClass1,TestClass2"
#                 for Travis to run only TestClass1 and TestClass2
#
# Dependencies:
#     - @salesforce/cli: This method needs to have sf installed in the server
#         We can install it by running "npm install @salesforce/cli --global" on before_install
function runTests() {
    if [ $# -lt 1 ]; then
        echo "Usage: runTests <sfdc auth url> [<test config>]"
        return -1
    fi

    local authUrl=$1
    local testConfig=$2

    echo $authUrl
    echo $testConfig

    local testParams=""
    case $testConfig in
        all)
            testParams="--test-level RunAllTestsInOrg"
        ;;
        local)
            testParams="--test-level RunLocalTests"
        ;;
        from-pr)
            source ./scripts/lib/gh.sh
            installAndSetUpGitHubCli "GH_TOKEN"
            testParams=$(getSfdxTestConfig $TRAVIS_PULL_REQUEST runTests)
        ;;
        from-env-var)
            testParams=$CI_RUN_TESTS_CONFIG
        ;;
    esac

    authenticateSfdxOrg sfdxurl $sfdcAuthUrl sfdcOrg

    echo "sf apex test run -o sfdcOrg -w -1 $testParams"
    sf apex test run -o sfdcOrg -w -1 $testParams
}

# runApexScripts runs all the apex scripts (with .apex extension) in a directory on a salesforce org. It can run them sequentially,
#     in alphabetical order, or in parallel.
#
# Parameters:
#     1. SFDC Auth URL: the force://... url (we can get it with sfdx force:org:display --verbose -u <org alias>)
#     2. Path to scripts: this is the path to the directory containing the apex scripts.
#     3. Run mode (optional): Values: "sequential" or "parallel". The default value is "sequential"
#
# Dependencies:
#     - @salesforce/cli: This method needs to have sf installed in the server
#         We can install it by running "npm install @salesforce/cli --global" on before_install.
function runApexScripts() {
    if [ $# -lt 2 ]; then
        echo "Usage: runApexScripts <sfdx auth url> <path/to/scripts> [<test config>]"
        return -1
    fi

    local sfdcAuthUrl=$1
    local scriptsDir=$2
    local mode=${3:-"sequential"}

    authenticateSfdxOrg sfdxurl $sfdcAuthUrl sfdcOrg

    if [[ $mode == "parallel" ]]; then
        local pids=()
        for apexScript in `ls ${scriptsDir}/*.apex`; do
            echo "Running --> sf apex run -o sfdcOrg --file $apexScript"
            sf apex run -o sfdcOrg --file $apexScript &
            pids+=($!)
        done

        for pid in $pids; do
            wait $pid
        done
    else
        for apexScript in `ls ${scriptsDir}/*.apex`; do
            echo "Running --> sf apex run -o sfdcOrg --file $apexScript"
            sf apex run -o sfdcOrg --file $apexScript
        done
    fi
}

# parseProject captures the project from a label: tag, branch, etc...
#   If it can match a project, it will return it in uppercase.
#   If no block is found, it will return an empty string.
#   By default, it will use '(.+)-v[0-9]+\.[0-9]+\.[0-9]+.*' regex to match non-production tags.
#   I.e. By default"test-v1.0.0" It returns TEST.
#
# Parameters:
#     1. label: label from where we'll try to extract the project.
#     2. pattern: regex patern to extract the project, it must have a capture group.
#         I.e. '(.+)-v[0-9]+\.[0-9]+\.[0-9]+.*' which is the default value
function parseProject() {
    if [ $# -lt 1 ]; then
        echo ""
    fi

    local label=$1
    local pattern=${2:-'(.+)-v[0-9]+\.[0-9]+\.[0-9]+.*'}
    
    [[ $label =~ $pattern ]]

    echo ${BASH_REMATCH[1]^^}
}

# getTestConfig gets the test config for a "sfdx source deploy" command.
#   It looks for json files in the directory provided in the parameter "testsDir",
#       or in a directory named "tests" if "testsDir" is not provided.
#   The json files need to have the following attributes:
#       - testLevel: the accepted values are NoTestRun, RunSpecifiedTests, RunLocalTests and RunAllTestsInOrg
#       - tests: only for RunSpecifiedTests test level, it's an array with the tests we want to run.
#   getTestConfig will use the higher testLevel in the json files:
#       1st RunAllTestsInOrg
#       2nd RunLocalTests
#       3rd RunSpecifiedTests
#           In this case, it will compile a list of all the tests in the json files.
#       4th NoTestRun
#
# Parameters:
#     1. testsDir: directory where the json files specifying the tests are.
#       Default value: "tests"
function getTestConfig() {
  testsDir=${1:-"tests"}

  if [ ! -d $testsDir ]; then
    echo ""
    return
  fi

  declare -A list_tests

  OIFS=$IFS
  IFS=$(echo -en "\n\b")
  testLevel=""
  for testfile in $(find $testsDir -name "*.json" -type f); do
    testLevelInFile=$(cat "$testfile" | jq '.testLevel')
    testLevelInFile=${testLevelInFile//\"/}
    if [ "$testLevelInFile" == "RunLocalTests" ] || [ "$testLevelInFile" == "RunAllTestsInOrg" ]; then
      testLevel=$testLevelInFile
      break
    fi

    if [ "$testLevelInFile" == "RunSpecifiedTests" ]; then
      testLevel=$testLevelInFile

      readarray -t TESTS < <(cat "$testfile" | jq '.tests[]')
      for TEST in ${TESTS[@]}; do
        list_tests["${TEST//\"/}"]=true
      done
    fi
  done
  IFS=$OIFS

  testConfig=""
  if [ "$testLevel" != "" ]; then
    testConfig="--test-level $testLevel"
    if [ "$testLevel" == "RunSpecifiedTests" ]; then
      tests=""
      for test in ${!list_tests[@]}; do
        tests="--tests $test $tests"
      done
      testConfig="$testConfig $tests"
    fi
  fi

  echo $testConfig
}

# getCIAuthUrlVarName gets the variable holding SFDX Auth URL for the CI org for a given destination
#   SFDX Auth URL variable name if we have them configured.
#   It checks the environment variables for one or more variables that starts with the given variable name
#       and follows with _CI. I.e. For MERGE_AUTH_URL, it will find all the MERGE_AUTH_URL_CI.*
#       environment variables.
#   Then if it finds only one, it will return that one for the calling script to use it.
#   If there is none, it will return an empty string.
#   If there is more than one, it will use calculate which one to use using the modulus of the TRAVIS_BUILD_NUMBER
#
# Parameters:
#     1. destAuthUrlVarName: the environment variable name containing the SFDX Auth URL for the destination org.
#       I.e. MERGE_AUTH_URL
function getCIAuthUrlVarName() {
    if [ $# -lt 1 ]; then
        echo ""
    fi

    destAuthUrlVarName=$1

    ciAuthUrlVars=$(env | egrep ^${destAuthUrlVarName}_CI | wc -l)

    if [ $ciAuthUrlVars -le 0 ]; then
        echo ""
    elif [ $ciAuthUrlVars -eq 1 ]; then
        ciVarNameParts=($(env | egrep ^${destAuthUrlVarName}_CI | tr "=" "\n"))
        echo ${ciVarNameParts[0]}
    else
        ciAuthUrlIdx=$(expr ${TRAVIS_BUILD_NUMBER:-0} % $ciAuthUrlVars + 1)
        echo "${destAuthUrlVarName}_CI_${ciAuthUrlIdx}"
    fi
}
