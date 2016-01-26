require 'bundler/setup'
Bundler.require
Dotenv.load

require 'open-uri'
require 'json'
require 'pry'
require 'active_support/core_ext'
require 'fileutils'

class NameCsvGenerator
  include Sidekiq::Worker
  include Everypoliticianbot::Github

  def perform(countries_json_url)
    with_git_repo('everypolitician/everypolitician-names', branch: 'gh-pages', message: 'Update names.csv') do

      countries = JSON.parse(open(countries_json_url).read, symbolize_names: true)

      CSV.open('names.csv','w') do |output_csv|
        headers = [:id, :name, :country, :legislature]
        output_csv << headers

        countries.each do |c|
          c[:legislatures].each do |l|
            legislature_namefile = File.join(File.dirname(l[:popolo]), 'names.csv')
            warn legislature_namefile
            legislature_names = open("https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/#{legislature_namefile}").read
            csv = CSV.new(legislature_names, headers: true, header_converters: :symbol)
            csv.each do |row|
              row[:country] = c[:slug]
              row[:legislature] = l[:slug]
              output_csv << row.values_at(*headers)
            end
          end
        end
      end
    end
  end
end

post '/' do
  everypolitician_event = request.env['HTTP_X_EVERYPOLITICIAN_EVENT']
  if everypolitician_event == 'pull_request_merged'
    request.body.rewind
    payload = JSON.parse(request.body.read, symbolize_names: true)
    job_id = NameCsvGenerator.perform_async(payload[:countries_json_url])
    "Queued job #{job_id}"
  else
    "Unhandled event #{everypolitician_event}"
  end
end

get '/' do
  'This is everypolitician-names, waiting to receive a webhook POST request to this URL.'
end
