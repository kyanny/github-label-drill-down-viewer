require 'sinatra'
require 'octokit'
require 'slim'
require 'active_support/all'
require 'pp'

configure do
  $cache = {}
end

helpers do
  def client
    @client ||= Octokit::Client.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
  end

  def repo
    ENV['GITHUB_REPO']
  end

  def repo_link
    "https://github.com/#{repo}"
  end

  def repo_link_tag
    %Q!<a href="#{repo_link}" target="_blank">#{repo}</a>!
  end

  def cache(key, &block)
    if $cache[key].present?
      puts "cache hit #{key}"
      $cache[key]
    else
      puts "cache miss #{key}"
      $cache[key] = yield
    end
  end

  def labels(selected_labels)
    if selected_labels.present?
      _labels = selected_labels.map { |label| label.name }.join(",")
      @labels = cache(_labels) do
        client.issues(repo, labels: _labels).flat_map { |issue| issue.labels }.uniq { |label| label.name }.sort_by { |label| label.name }
      end
    else
      @labels = cache(_labels) do
        client.labels(repo).sort_by { |label| label.name }
      end
    end
  end

  def count_issues(*labels)
    return
    @count_issues ||= {}
    labels.flatten!
    return if labels.length < 2
    _labels = labels.map { |label| label.name }.join(",")
    cache("#{_labels}:count") do
      client.issues(repo, labels: _labels).count
    end
  end

  def build_query(*labels)
    labels.flatten!
    _labels = labels.map { |label| "label[]=#{label.name}" }.join("&")
  end

  def build_github_query(*labels)
    labels.flatten!
    _labels = labels.map { |label| "label:\"#{label.name}\"" }.join(" ")
    URI.escape("is:open is:issue #{_labels}")
  end

  def text_color(background_color)
    background_color =~ /^[def].[def].[def].$/i ? '000' : 'fff'
  end
end

get '/' do
  @selected_labels = Array(params['label']).map { |label|
    client.label(repo, label)
  }
  @labels = labels(@selected_labels)
  slim :index
end
