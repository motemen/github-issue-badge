require 'octokit'
require 'sinatra'
require 'slim'
require 'faraday'
require 'faraday_middleware'
require 'logger'

## Configuration

GITHUB_OAUTH_CLIENT_ID     = ENV['GITHUB_OAUTH_CLIENT_ID']
GITHUB_OAUTH_CLIENT_SECRET = ENV['GITHUB_OAUTH_CLIENT_SECRET']
GITHUB_OAUTH_ACCESS_TOKEN  = ENV['GITHUB_OAUTH_ACCESS_TOKEN']
GITHUB_API_ENDPOINT        = ENV['GITHUB_API_ENDPOINT']

unless (GITHUB_OAUTH_CLIENT_ID && GITHUB_OAUTH_CLIENT_SECRET) || GITHUB_OAUTH_ACCESS_TOKEN
  raise 'You should specify either GITHUB_OAUTH_CLIENT_ID, GITHUB_OAUTH_CLIENT_SECRET pair or GITHUB_OAUTH_ACCESS_TOKEN'
end

## Dimensions

BADGE_HEIGHT = 20
LABEL_WIDTH  =  8
ICON_SIZE    = BADGE_HEIGHT

def conn
  Faraday.new do |conn|
    conn.request  :json
    conn.response :json, content_type: /\bjson$/
    conn.response :logger, Logger.new(STDERR).tap { |logger| logger.level = Logger::INFO }
    conn.adapter  Faraday.default_adapter
  end
end

class Issue
  STATE_COLORS = {
    'open'   => '6CC644',
    'merged' => '6E5494',
    'closed' => 'BD2C00',
  }

  def initialize(octokit, repo, number)
    @issue = octokit.issue(repo, number)

    pr_merged = @issue.state == 'closed' and
                @issue.pull_request and
                octokit.pull_merged?(repo, number)
    @state = pr_merged ? 'merged' : @issue.state
  end

  extend Forwardable
  def_delegators :@issue, :labels, :assignee, :user, :number

  attr_reader :state

  def state_color
    STATE_COLORS[state]
  end

  def assignee_avatar_url
    avatar_data_url(@issue.assignee)
  end

  def user_avatar_url
    avatar_data_url(@issue.user)
  end

  private

  def avatar_data_url(user)
    return unless user and user.avatar_url

    url = URI(user.avatar_url)
    url.query = url.query ? "#{url.query}&s=20" : 's=20'

    resp = conn.get(url)
    "data:#{resp.headers['Content-Type']};base64,#{Base64.strict_encode64(resp.body)}"
  end
end

def badge_message (status, message)
  slim :message, locals: { status: status, message: message }, content_type: 'image/svg+xml'
end

def halt_badge_message (status, message)
  halt status, badge_message(status, message)
end

get '/auth' do
  halt 404 unless GITHUB_OAUTH_CLIENT_ID && GITHUB_OAUTH_CLIENT_SECRET

  scope = if params[:only] == 'public'
    'public_repo'
  else
    'repo'
  end

  redirect "https://github.com/login/oauth/authorize?client_id=#{GITHUB_OAUTH_CLIENT_ID}&scope=#{scope}"
end

get '/auth/callback' do
  halt 404 unless GITHUB_OAUTH_CLIENT_ID && GITHUB_OAUTH_CLIENT_SECRET

  code = params[:code] or halt_badge_message 400, 'Bad Request'
  resp = conn.post(
    'https://github.com/login/oauth/access_token',
    { 'client_id' => GITHUB_OAUTH_CLIENT_ID, 'client_secret' => GITHUB_OAUTH_CLIENT_SECRET, 'code' => code },
    { 'Accept' => 'application/json' }
  )
  if not resp.success? or resp.body['error']
    logger.error resp.body['error']
    halt_badge_message 500, 'Auth failed'
  end

  session[:access_token] = resp.body['access_token']

  badge_message 200, 'Authorized'
end

get '/badge/:owner/:repo/:number' do
  access_token = session[:access_token] || GITHUB_OAUTH_ACCESS_TOKEN
  unless access_token
    halt_badge_message 403, 'Visit /auth'
  end

  client = Octokit::Client.new(access_token: access_token)
  if GITHUB_API_ENDPOINT
    client.api_endpoint = GITHUB_API_ENDPOINT
  end

  issue = begin
    Issue.new(client, { owner: params[:owner], repo: params[:repo] }, params[:number])
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
