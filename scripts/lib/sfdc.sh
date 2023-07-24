# Lib with Salesforce utilitiy functions

# authenticateOrg will authenticate an Org with sfdx
#
# Parameters:
#   1. authMethod: the authentication method we want to use. Possible values: sfdxurl.
#   
#   Extra params for "sfdxurl" authentication method:
#       2. Authentication SFDX URL: The force://... url (we can get it with sfdx force:org:display --verbose -u <org alias>)
#       3. Org Alias (optional): if not provided it will use "targetOrg" as value.
#
# Dependencies:
#    - sfdx-cli: needs to have sfdx cli installed in the server
#        We can installing by running "npm install sfdx-cli"
function authenticateSfdxOrg() {
    if [ $# -lt 1 ]; then
                echo "Usage: authenticateSfdxOrg <Authentication Method> [<Specific arguments for the auth method>, ...]"
                return -1
    fi

    local authMethod=$1;
    case $authMethod in
        "sfdxurl")
            if [ $# -lt 2 ]; then
                echo "Usage: authenticateSfdxOrg sfdxurl <Authentication SFDX URL> [<ORG Alias>]"
                return -1
            fi
            local sfdxUrl=$2
            local orgAlias=${3:-targetOrg}
            echo $sfdxUrl > .sfdx-deploy-url
            sf org login sfdx-url --sfdx-url-file ./.sfdx-deploy-url --alias $orgAlias
        ;;
    
        *)
            echo "Unknown Authentication Method: '${authMethod}'"
            return -1
        ;;
    esac
}

# createDeltaPackage uses SFDX Git Delta plugin to create a delta package (including destructive changes is any) with the metadata
#     that changed between 2 given commits
#
# Parameters:
#     1. deltaDirectory: This is the path of the directory where the delta package will be created.
#         If the directory doesn't exist it will be created.
#         If the directory already exists it won't clean it up.
#     2. commitRange: This is the git commit range using the following format "<to_commit>...<from_commit>" or a single commit.
#         In case we get a single commit or a tag or a branch name, it will use it as <from_commit> and HEAD as <to_commit>.
#         I.e. In Travis-CI we could pass $TRAVIS_COMMIT_RANGE or $TRAVIS_TAG
#     3. onlyManifest (optional): This is flag (true|false) that defines if we only want to generate the manifest.
#         By default it's false, so it will generate the whole package.
#         If any other value than "true" is provided, it will default to false.
#
# Dependencies:
#     - sfdx-cli: This method needs to have sfdx installed in the server
#         We can installing by running "npm install sfdx-cli"
#     - sfdx-git-delta pluging: This method requires us to have sfdx-git-delta installed
#         We can install it by running "yes | sfdx plugins:install sfdx-git-delta"
function createDeltaPackage() {
    if [ $# -lt 2 ]; then
        echo "Usage: createDeltaPackage <path delta directory> <commit range | commit> [<only manifest>]"
        return -1
    fi

    local deltaDirectory=$1
    local commitRange=$2
    local onlyManifest=${3:-false}
    
    mkdir -p $deltaDirectory
    if [[ $commitRange == *"..."* ]]; then
        local commits=($(echo $commitRange | tr "..." " "))
    else
        local commits=($commitRange "HEAD")
    fi

    local defaultDir=$(jq '.packageDirectories[] | select(.default) | .path' sfdx-project.json | tr -d '"')
    local sourceConfig="";

    if [ ! -z "$defaultDir" ]; then
        sourceConfig="--source $defaultDir"
    fi

    git fetch --tags
    
    if [[ $onlyManifest == "true" ]]; then
        echo "sf sgd source delta --to \"${commits[0]}\" --from \"${commits[1]}\" --output $deltaDirectory $sourceConfig"
        sf sgd source delta --to "${commits[0]}" --from "${commits[1]}" --output $deltaDirectory $sourceConfig
    else
        echo "sf sgd source delta --to \"HEAD\" --from \"${commits[0]}\" --output $deltaDirectory $sourceConfig --generate-delta"
        sf sgd source delta --to "HEAD" --from "${commits[0]}" --output $deltaDirectory $sourceConfig --generate-delta
    fi
}
