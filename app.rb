require 'bundler/setup'
Bundler.require

require 'open-uri'
require 'json'
require 'pry'

get '/:country/:legislature' do |country_slug, legislature_slug|
  redirect to("/#{country_slug}/#{legislature_slug}/persons/")
end

get '/:country/:legislature/persons/?' do |country_slug, legislature_slug|
  countries_json = JSON.parse(open('https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/countries.json').read, symbolize_names: true)
  country = countries_json.find { |c| c[:slug] == country_slug }
  legislature = country[:legislatures].find { |l| l[:slug] == legislature_slug }
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
  content_type :json
  JSON.pretty_generate(
    total: people.size,
    page: 1,
    per_page: people.size,
    has_more: false,
    result: people
  )
end
