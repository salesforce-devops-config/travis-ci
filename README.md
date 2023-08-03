# Salesforce DevOps Travis Configuration Base
If you are evaluating tools to start implementing Salesforce DevOps, Travis-CI should be one of the tools you should look into.

We can use the Travis-CI configuration in repository and GitHub to implement these [Salesforce deployment pipelines](https://devops.guerrero.zone/02-pipelines.html) to use this [Salesforce DevOps Strategy](https://devops.guerrero.zone/01-devops-strategy.html).

## Preparing Your Repository with this Travis-CI Configuration
First, you need to clone this repository in a separate directory (not in your salesforce repository).

Then you need to copy the content of `config` directory of the Travis-CI repo inside the `config` directory of your repository, if you don't have a `config` directory in your repository, then just copy the whole `config` directory to the root of your directory (the root directory of your project is the directory that contains the sfdx-project.json file).

After that, if there's no `script` directory in your project, copy the whole `script` directory from the Travis-CI repo to the root of your repository, if you already have this `script` directory, copy the content of the `script` directory from the Travis-CI repository inside the `script` directory of your project.

Then copy the directories `rulesets` and `tests` and the files `.travis.yml`, `.pretierrc.yaml`, `package.json` and `sfdx-project.string-replacement.example.json` to the root of your project.

After doing this, go to your Travis-CI dashboard and find your salesforce's project repository, and in settings make sure to disable building for branches and pull requests, as we don't want Travis being triggered yet.

Once Travis-CI is disabled for your salesforce repository you can stage, commit and push the new Travis-CI configuration and supporting scripts to your repository.

Next step is to start implementing the pipeline, which you will do by creating branches and tags in git and adding environment variables in Travis-CI according with the needs of your pipeline.
