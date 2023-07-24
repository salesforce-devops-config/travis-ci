function assertValidPullRequest() {
  ALLOWED_BRANCHES="release, cs-enhancements"

  if [[ "${MAIN_PR_ALLOWED_BRANCHES}" != "" ]]; then
    ALLOWED_BRANCHES="${ALLOWED_BRANCHES},${MAIN_PR_ALLOWED_BRANCHES}";
  fi
  BRANCHES=($(echo $ALLOWED_BRANCHES | tr "," "\n"))
  FOUND_ALLOWED_BRANCH=false

  for branch in "${BRANCHES[@]}"; do
    if [[ "$branch" == "${TRAVIS_PULL_REQUEST_BRANCH}" ]]; then
      FOUND_ALLOWED_BRANCH=true;
      break;
    fi
  done

  if [[ "${TRAVIS_EVENT_TYPE}" == "pull_request" ]] && \
    ([[ "${TRAVIS_BRANCH}" == "main" ]] || [[ "${TRAVIS_BRANCH}" == "master" ]]) && \
    [[ ${FOUND_ALLOWED_BRANCH} == false ]]
  then
    echo "Shouldn't create PRs from ${TRAVIS_PULL_REQUEST_BRANCH} branch to main or master branches. To enable them, add the branch name to MAIN_PR_ALLOWED_BRANCHES environment variable (as comma separated list)";
  fi
}