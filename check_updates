#!/usr/bin/env bash

set -o nounset -o pipefail -o errexit

rg "CTOP_VERSION=" install/
github_last_release bcicen/ctop

rg "SYNCTHING_VERSION=" install/
github_last_release syncthing/syncthing

rg "TERRAFORM_VERSION=" install/
github_last_release hashicorp/terraform
