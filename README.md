# everypolitician-names

A little app that reads all the names of all the politicians in the world
and publishes them in a single CSV file.

The data comes from the
[EveryPolitician project](http://everypolitician.org).

The file of names is published here:
[https://everypolitician.github.io/everypolitician-names/names.csv](https://everypolitician.github.io/everypolitician-names/names.csv)
 -- be careful, that's quite a big file because there are lots of politicians!
 
That file is actually `names.csv` in the `gh_pages` branch of *this* repo.

The EveryPoliticianBot has [blogged about `everypolitician-names`](https://medium.com/@everypolitician/i-make-lists-of-humans-names-4b061212baf3).

## What's in names.csv?

All the politicians' names that are in the EveryPolitician data. Some
polticians have more than one name. Often a politician has more than 
one name because it's written in more than one language.

The CSV (comma separated values) file has a header line, and then one line for
every name. There are four values on each line:

* `id` -- a unique id for the politician, that you can use to determine when
  two or more names are for the same politician (if you need to know). You can
  also use this to match it with other data from EveryPolitician.

* `name` -- the name of the politician.

* `country` and `legislature` -- so you can tell which country and legislature
  this politician is from.

That's all -- if you need richer data (for example, you really need to know
what language a name is in), it's all avalailable from EveryPolitician.org
(look in the Popolo JSON for the full details).

### Nerdy detail

We're actually running this as a wee Sinatra app on Heroku that runs whenever
EveryPolitician's data updates (the app is subscribed to 
[EveryPolitician's update alerts](https://everypolitician-app-manager.herokuapp.com/)),
which gets that latest data and compiles it into a new `names.csv` file which
it then commits to its *own* `gh_pages` branch, so it's automagically
published in GitHub pages. Yeah.

---

## For developers: install

First you'll need make sure you've got a couple of system packages installed:

- ruby >= 2.2.3 (`brew install ruby` on a mac)
- redis (`brew install redis` on a mac)

Then you'll need to install some required gems:

    gem install bundler foreman

If installing gems fails with a permissions error you may need to prefix the
command with `sudo`.

Next clone the repository from GitHub and change into the cloned directory:

    git clone https://github.com/everypolitician/everypolitician-names.git
    cd everypolitician-names

Now you need to install the project dependencies with bundler:

    bundle install

Finally you'll need to
[create a Personal Access Token on GitHub](http://github.com/settings/tokens).
The default scopes are fine. Then copy `.env.example` to `.env` and add the generated access token.

    cp .env.example .env
    $EDITOR .env
    # Replace 'replace_with_github_access_token' with an actual access token

## Usage

To start the application's web and worker processes you can use foreman:

    foreman start

Then to trigger a rebuild you can manually hit the `/` endpoint (note this must
be a POST request, because we're anticipating this really coming from the
EveryPolitician app-manager, which sends POSTs):

    curl -i -X POST http://localhost:5000/

## Architecture

The `/` endpoint is registered to receive webhooks from EveryPolitician
whenever there's a change to
[`countries.json`](https://github.com/everypolitician/everypolitician-data/blob/master/countries.json).
When a webhook is received a `NameCsvGenerator` background job is queued.

The `NameCsvGenerator#perform` method does the bulk of the work. First it
clones the
[everypolitician/everypolitician-names](https://github.com/everypolitician/everypolitician-names)
repository, then it switches to the `gh-pages` branch and runs the code in the
block that's passed to `with_git_repo`. It pulls in each of the `names.csv`
files that EveryPolitician currently generates for each legislature, and writes
them out as one big CSV `names.csv` into that `gh_pages` branch.

Once the `with_git_repo` block finishes, any changes to the cloned repository
are committed with the provided message and pushed back to GitHub.
