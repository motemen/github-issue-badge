# GitHub Issue Badge

http://github-issue-badge.herokuapp.com/

GitHub issue/Pull Request information in embeddable images.

![Badge](docs/badge-4x.png)

- Issue#
- Status (open/closed/merged)
- Author or assignee
- Labels

## Usage

- Visit [/auth](http://github-issue-badge.herokuapp.com/auth) to authorize application.
  - If you dislike `repo` scope, visit [/auth?only=public](http://github-issue-badge.herokuapp.com/auth?only=public) to allow `public_repo` scope only.
- Visit `/badge/:user/:repo/:number` to get the badge.
  - eg. http://github-issue-badge.herokuapp.com/badge/motemen/test-repository/5

## Deploy your own

- [![Deploy](https://www.herokucdn.com/deploy/button.png)](https://www.heroku.com/deploy/?template=https://github.com/motemen/github-issue-badge)
- or: `fig up`
- or: set up Redis and run the Rack app

## Environment variables

### `GITHUB_OAUTH_CLIENT_ID`, `GITHUB_OAUTH_CLIENT_SECRET`

Required for OAuth authorization. If you specify `GITHUB_OAUTH_ACCESS_TOKEN` below, these are not required.

### `GITHUB_OAUTH_ACCESS_TOKEN`

Specify your own access token to allow visitors use the app without authorizing application by OAuth.

### `GITHUB_API_ENDPOINT`

If you want to use this app on GitHub:Enterprise, specify this environment variable.

### `REDIS_URL`

You don't need to set this variable if you run this app on Heroku or by fig.

## Chrome extension

https://github.com/motemen/chrome-Embed-GitHub-Issue-Badges
