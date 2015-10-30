# everypolitician-writeinpublic

An adapter to turn [EveryPolitician](http://everypolitician.org) [Popolo](http://www.popoloproject.com) data into a format that [WriteInPublic](http://writeinpublic.com/en/) understands.

## Install

First you'll need make sure you've got a couple of system packages installed:

- ruby >= 2.0.0 (`brew install ruby` on a mac)
- redis (`brew install redis` on a mac)

Then you'll need to install some required gems:

    gem install bundler foreman

If installing gems fails with a permissions error you may need to prefix the command with `sudo`.

Next clone the repository from GitHub and change into the cloned directory.

    git clone https://github.com/everypolitician/everypolitician-writeinpublic.git
    cd everypolitician-writeinpublic

Now you need to install the project dependencies with bundler

    bundle install

Finally you'll need to [create a Personal Access Token on GitHub](http://github.com/settings/tokens). The default scopes are fine. Then copy `.env.example` to `.env` and add the generated access token.

    cp .env.example .env
    $EDITOR .env
    # Replace 'replace_with_github_access_token' with an actual access token

## Usage

To start the application's web and worker processes you can use foreman:

    foreman start

Then to trigger a rebuild you can manually hit the `/event_handler` endpoint:

    curl -i -X POST http://localhost:5000/event_handler

## Architecture

The `/event_handler` endpoint is registered to receive webhooks from EveryPolitician whenever there's a change to [`countries.json`](https://github.com/everypolitician/everypolitician-data/blob/master/countries.json). When a webhook is received a `RebuildLegislatureFiles` background job us queued.

The `RebuildLegislatureFiles#perform` method does the bulk of the work. First it clones the [everypolitician/everypolitician-writeinpublic](https://github.com/everypolitician/everypolitician-writeinpublic) repository, then it switches to the `gh-pages` branch and runs the code in the block that's passed to `with_git_repo`. Once the `with_git_repo` block finishes any changes to the clones repository are committed with the provided message and pushed back to GitHub.
