require 'octokit'
require 'sinatra'
require 'slim'

BADGE_HEIGHT = 20
LABEL_WIDTH  =  8
ICON_SIZE    = BADGE_HEIGHT

def client
  @client ||= Octokit::Client.new
end

class Issue
  extend Forwardable

  STATE_COLORS = {
    'open'   => '6CC644',
    'merged' => '6E5494',
    'closed' => 'BD2C00',
  }

  def self.fetch(repo, number)
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

get '/badge/:owner/:repo/:number' do
  issue = begin
    Issue.fetch({ owner: params[:owner], repo: params[:repo] }, params[:number])
  rescue Octokit::NotFound
    halt 404, { 'Content-Type' => 'text/plain' }, '404 Issue Not Found'
  end

  # not so correct :P
  number_width = 15 + issue.number.to_s.length * 9
  state_width  = 10 + issue.state.length * 7

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
