#!/bin/env ruby

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('Gemfile', __dir__)

require 'rubygems'
require 'bundler/setup'
require 'byebug'
require 'erb'
require 'dotenv/load'
require 'faraday'

query = <<~GQL
  query {
    user(login: "kiskoza") {
      pullRequests(
        first: 100,
        orderBy: {field: UPDATED_AT, direction: DESC}
      ) {
        nodes {
          repository {
            nameWithOwner
          }
          title
        }
      }
    }
  }
GQL

ignored_repos = File.open('ignored_repos.list').readlines.map(&:strip)

recent_repositories = Faraday
  .new(url: 'https://api.github.com/graphql',
       headers: {
         'Content-Type' => 'application/json',
         'Authorization' => "Bearer #{ENV['GITHUB_TOKEN']}"
       })
  .then { _1.post('', { query:, variables: {} }.to_json) }
  .then { JSON.parse(_1.body, symbolize_names: true) }
  .dig(:data, :user, :pullRequests, :nodes)
  .map { _1.dig(:repository, :nameWithOwner) }
  .reject { ignored_repos.include?(_1) }
  .uniq
  .map { _1.split('/') }


File.read('README.md.erb')
  .then { ERB.new(_1).result(binding) }
  .then { File.write('README.md', _1) }
