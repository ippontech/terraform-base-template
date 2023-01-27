# Contributing

:+1: :tada: First off, thanks for taking the time to contribute! :tada: :+1:

The following is a set of guidelines for contributing to **<MODULE_NAME>**. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

## Table of Content

<!--TOC-->

- [Contributing](#contributing)
    - [Table of Content](#table-of-content)
    - [Developers Information](#developers-information)
        - [First steps after having cloned/forked](#first-steps-after-having-clonedforked)
    - [Tools used](#tools-used)
        - [Pre-commit](#pre-commit)
        - [Makefile Usage](#makefile-usage)
    - [Styleguides](#styleguides)
        - [Git Commit Messages](#git-commit-messages)
        - [Documentation Styleguide](#documentation-styleguide)

<!--TOC-->

## Developers Information
### First steps after having cloned/forked

* Set up pre-commit
  ```shell
  pre-commit install # install pre-commit (see the ## Tools used section for more infos)
  pre-commit autoupdate # will update the hooks of the .pre-commit-config.yaml to the latest tagged version
  # if there is any update :
  git commit -am ":wrench: autoupdate pre-commit hooks"
  ```
* Search and replace the `<MODULE_NAME>` by your... module name.
* Search for the TODO string in the repo's file and customize them accordingly
* Check the release Makefile section below
    * Related files :
        * Makefile
        * .release/*
        * .releaserc
        * CHANGELOG.md
* Update the version of Terraform to use in the [`version.tf`](../version.tf).
* Run a `make precommit` command

<TODO ADD ANY OTHER USEFUL INFORMATION HERE>

## Tools used

### Pre-commit

To facilitate testing before committing to gitlab, you have the option of running automated tests with pre-commit. Each hook enables a test that we can customize.
This tool will helps us improving the feedback loop and ensure our code stays compliant, documented and that we don't insert any secrets (these are exemples of useful hooks already pre-configured in this repo).

Needed files for pre-commit hooks configuration :
* .pre-commit-config/*
* .
#### The main hooks configured

##### Linting

###### terraform_tflint

To ensure that the terraform code does not present any problem of typing or forgetting, we use `terraform_tflint`.

###### terraform-fmt

To ensure an automatic correction of the terraform code and keep a good indentation, we use `terraform-fmt`.

###### terraform_docs

For compliance we use `terraform_docs` tools, this will update the readme automatically with terraform inputs and outputs.

###### shellcheck

To check the quality of linux code and make automatic corrections, we use `shellcheck`

###### md-toc

To ensure an automatic generation of markdown *Table of content*, the `md-toc` hook is used.

##### Security

###### detect-secrets

Not to commit a key, access key or credential in clear on gitlab, we've set up the `detect-secrets` hook
which will alert before committing chosen sensitive secrets. This hook comes with the `.secrets.baseline` file to chose which secrets you want to catch.

###### tfsec

To avoid committing aws resources presenting security vulnerabilities, we use `tfsec` which allows to analyze the deployed resources and indicates what is not in accordance with good security practice rules.

#### Install dependencies

* [`pre-commit`](https://pre-commit.com/#install)
* [`terraform-docs`](https://github.com/segmentio/terraform-docs) required for `terraform_docs` hooks. `GNU awk` is required if using `terraform-docs` older than 0.8.0 with Terraform 0.12.
* [`TFLint`](https://github.com/terraform-linters/tflint) required for `terraform_tflint` hook.
* [`TFSec`](https://github.com/liamg/tfsec) required for `terraform_tfsec` hook.


#### Usage Pre-commit

To execution automated on commit you can install pre-commit on your repo folder

```bash
pre-commit install
```

To perform code test manually, you must run the precommit before pushing your code
like this:

```bash
pre-commit install
pre-commit run --all
```

### Makefile Usage

**Warning** : Don't tag manually.

```bash
> make help

version         Get current version
check-status    Check current git status
check-release   Check release status
major-release   Do a major-release, ie : bumped first digit X+1.y.z
minor-release   Do a minor-release, ie : bumped second digit x.Y+1.z
patch-release   Do a patch-release, ie : bumped third digit x.y.Z+1
help            Show this help (Run make <target> V=1 to enable verbose)
```


## Styleguides

### Git Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit commit title to 48 characters or less
* Reference issues and pull requests liberally in commit title/message
* Consider starting the commit message with an applicable [emoji](https://gitmoji.dev/) like :
    * :sparkles: `:sparkles:` when introducing new features
    * :recycle: `:recycle:` when refactoring code
    * :art: `:art:` when improving the format/structure of the code
    * :zap: `:zap:` when improving performance
    * :memo: `:memo:` when writing docs
    * :bug: `:bug:` when fixing a bug
    * :fire: `:fire:` when removing code or files
    * :green_heart: `:green_heart:` when fixing the CI build
    * :pushpin: `:pushpin:` when pinning dependencies to specific version
    * :arrow_up: `:arrow_up:` when upgrading dependencies
    * :arrow_down: `:arrow_down:` when downgrading dependencies
    * :rotating_light: `:rotating_light:` when removing linter warnings

### Documentation Styleguide

* As we use [terraform-docs](https://github.com/terraform-docs/terraform-docs), please to describe all inputs and outputs.
* Use [Markdown](https://daringfireball.net/projects/markdown).