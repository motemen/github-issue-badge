require 'octokit'
require 'sinatra'
require 'slim'
require 'httparty'

BADGE_HEIGHT = 20
LABEL_WIDTH  =  8
ICON_SIZE    = BADGE_HEIGHT

GITHUB_OAUTH_CLIENT_ID     = ENV.fetch('GITHUB_OAUTH_CLIENT_ID')
GITHUB_OAUTH_CLIENT_SECRET = ENV.fetch('GITHUB_OAUTH_CLIENT_SECRET')

class Issue
  extend Forwardable

  STATE_COLORS = {
    'open'   => '6CC644',
    'merged' => '6E5494',
    'closed' => 'BD2C00',
  }

  def self.fetch(client, repo, number)
    issue = client.issue(repo, number)
    pr_merged = issue.state == 'closed' && issue.pull_request && client.pull_merged?(repo, number)

    self.new(issue, pr_merged)
  end

  def initialize(octokit_issue, pr_merged)
    @issue = octokit_issue
    @pr_merged = pr_merged
  end

  def state
    @pr_merged ? 'merged' : @issue.state
  end

  def state_color
    STATE_COLORS[state]
  end

  def_delegators :@issue, :labels, :assignee, :user, :number
end

def badge_message (status, message)
  slim :message, locals: { status: status, message: message }, content_type: 'image/svg+xml'
end

def halt_badge_message (status, message)
  halt status, badge_message(status, message)
end

get '/auth' do
  redirect "https://github.com/login/oauth/authorize?client_id=#{GITHUB_OAUTH_CLIENT_ID}&scope=repo"
end

get '/auth/callback' do
  code = params[:code] or halt_badge_message 400, 'Bad Request'
  res = HTTParty.post(
    'https://github.com/login/oauth/access_token',
    headers: { 'Accept' => 'application/json' },
    body: { 'client_id' => GITHUB_OAUTH_CLIENT_ID, 'client_secret' => GITHUB_OAUTH_CLIENT_SECRET, 'code' => code }
  )
  session[:access_token] = res['access_token']

  badge_message 200, 'Authorized'
end

get '/badge/:owner/:repo/:number' do
  client = Octokit::Client.new(access_token: session[:access_token])

  issue = begin
    Issue.fetch(client, { owner: params[:owner], repo: params[:repo] }, params[:number])
  rescue Octokit::NotFound
    halt_badge_message 404, 'Not Found'
  end

  # not so correct :P
  number_width = 15 + issue.number.to_s.length * 9
  state_width  = 10 + issue.state.length * 7

  logger.info "Rate limit: #{client.rate_limit.remaining}/#{client.rate_limit.limit}"

  content_type 'image/svg+xml'
  slim :badge, locals: {
    badge_height: BADGE_HEIGHT,
    badge_width:  number_width + state_width + ICON_SIZE + LABEL_WIDTH * issue.labels.size,
    number_width: number_width,
    state_width:  state_width,
    icon_size:    BADGE_HEIGHT,
    label_width:  LABEL_WIDTH,
    issue:        issue,
  }
end
