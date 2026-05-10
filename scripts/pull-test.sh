#!/bin/bash

set -ex

fn=/tmp/cs-pull-test-mob-sandbox.log

name=$(gh codespace create --repo ciwg/mob-sandbox --branch main --display-name pull-test-mob-sandbox --default-permissions --status --machine basicLinux32gb --devcontainer-path .devcontainer/devcontainer.json)

gh codespace logs -c $name > $fn
echo $fn
