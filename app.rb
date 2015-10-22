require 'bundler/setup'
Bundler.require
Dotenv.load

require 'open-uri'
require 'json'
require 'pry'
require 'active_support/core_ext'
require 'fileutils'

class RebuildLegislatureFiles
  include Sidekiq::Worker
  include Everypoliticianbot::Github

  def perform
    with_git_repo('everypolitician/everypolitician-writeinpublic', branch: 'gh-pages', message: 'Update legislatures') do
      countries = JSON.parse(open('https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/countries.json').read, symbolize_names: true)
      output = []
      countries.each do |country|
        country[:legislatures].each do |legislature|
          warn "#{country[:name]} - #{legislature[:name]}"
          legislative_period = legislature[:legislative_periods].first
          csv = 'https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/' + legislative_period[:csv]
          popolo = nil
          Dir.mktmpdir do |dir|
            csv_file = File.join(dir, 'out.csv')
            File.write(csv_file, open(csv).read)
            popolo = Popolo::CSV.new(csv_file).data
          end
          people = popolo[:persons]
          people = people.map do |person|
            person[:memberships] = popolo[:memberships].find_all { |m| m[:person_id] == person[:id] }
            person[:contact_details] ||= []
            person
          end
          legislature_json_file = File.join(
            country[:slug],
            legislature[:slug],
            'persons.json'
          )
          FileUtils.mkdir_p(File.dirname(legislature_json_file))
          File.write(
            legislature_json_file,
            JSON.pretty_generate(
              total: people.size,
              page: 1,
              per_page: people.size,
              has_more: false,
              result: people
            )
          )
          output << {
            country: country[:name],
            legislature: legislature[:name],
            slug: [country[:slug], legislature[:slug]].join('-').parameterize,
            person_count: people.select { |p| !p[:end_date] }.size,
            people_with_contact_details: people.count { |p| !p[:email].to_s.empty? },
            url: "https://everypolitician-writeinpublic.herokuapp.com/#{country[:slug]}/#{legislature[:slug]}"
          }
        end
      end
      File.write('countries.json', JSON.pretty_generate(output))
    end
  end
end

post '/event_handler' do
  RebuildLegislatureFiles.perform_async
  'ok'
end

get '/:country/:legislature' do |country_slug, legislature_slug|
  redirect to("/#{country_slug}/#{legislature_slug}/persons/")
end

get '/:country/:legislature/persons/?' do |country_slug, legislature_slug|
  content_type 'application/json; charset=utf-8'
  url_base = 'https://everypolitician.github.io/everypolitician-writeinpublic'
  open(url_base + "/#{country_slug}/#{legislature_slug}/persons.json").read
end
