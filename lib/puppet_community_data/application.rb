require 'puppet_community_data'
require 'puppet_community_data/version'
require 'puppet_community_data/repository'
require 'puppet_community_data/pull_request'

require 'octokit'
require 'table_print'
require 'chronic'
require 'json'
require 'csv'
require 'google_drive'
require 'trollop'

module PuppetCommunityData
  class Application

    attr_reader :opts
    attr_writer :repositories

    ##
    # Initialize a new application instance.  See the run method to run the
    # application.
    #
    # @param [Array] argv The argument vector to use for options parsing.
    #
    # @param [Hash] env The environment hash to use for options parsing.
    def initialize(argv=ARGV, env=ENV.to_hash)
      @argv = argv
      @env  = env
      @opts = {}
    end

    ##
    # run the application.
    def run
      parse_options!

      pull_requests = closed_pull_requests("puppetlabs/hiera")
      write_to_json("/Users/haileekenney/Projects/puppet_community_data/data/lifetimes.json", pull_requests)
      write_to_csv("/Users/haileekenney/Projects/puppet_community_data/data/lifetimes.csv",pull_requests)
    end

    def version
      PuppetCommunityData::VERSION
    end

    def github_oauth_token
      return @opts[:github_oauth_token]
    end

    def github_api
      @github_api ||= Octokit::Client.new(:auto_traversal => true, :oauth_token => github_oauth_token)
    end

    def generate_repositories(repo_names)
      repos.each do |repo_name|
        repository.push(Repository.new(repo_name))
      end
    end

    def write_pull_request_to_database
      repositories.each do |repo|
        pull_requests = repo.closed_pull_requests(github_api)
        closed_pull_requests.each do |pull_request|
          pull_request.save_if_new
        end
      end
    end

    ##
    # Given a hash of pull requests as parsed by closed_pull_requests,
    # pull_request_lifetimes will generate an array of integers which
    # contains only the pull request lifetimes
    #
    # @param [Hash] pull_requests Pull requests sorted by number
    #
    # @return [Array] of pull requests lifetimes as integers
    #
    def pull_request_lifetimes(pull_requests)
      pull_request_lifetimes = Array.new

      pull_requests.each do |key, value|
        pull_request_lifetimes.push(value[0])
      end

      return pull_request_lifetimes
    end

    ##
    # parse_options parses the command line arguments and sets the @opts
    # instance variable in the application instance.
    #
    # @return [Hash] options hash
    def parse_options!
      env = @env

      @opts = Trollop.options(@argv) do
        version "Puppet Community Data #{version} (c) 2013 Puppet Labs"
        banner "---"
        text "Gather data from source repositories and produce metrics."
        text ""
        opt :github_oauth_token, "The oauth token to create instange of GitHub API (PCD_GITHUB_OAUTH_TOKEN)",
          :default => (env['PCD_GITHUB_OAUTH_TOKEN'] || '1234changeme')
      end
    end

    ##
    # write_to_json takes a given input, converts it to json,
    # and writes it to the specified file path
    #
    # @param [String] file_name is the file the data will
    # be written to
    # @param [Array, Hash] to_write is the data to be written
    def write_to_json(file_name, to_write)
      write(file_name, JSON.pretty_generate(to_write))
    end

    ##
    # write_to_csv takes the given input, parses it
    # appropriately, and writes it to the specified file path
    #
    # @param [String] file_name is the file the data will be
    # written to
    # @param [Array, Hash] to_write is the data to be written
    def write_to_csv(file_name, to_write)
      if(to_write.kind_of?(Hash))
        csv_hash_write(file_name, to_write)
      else
        csv_array_write(file_name, to_write)
      end
    end

    ##
    # write is a private delegate method to make it easier to test File.open
    #
    # @api private
    def write(filename, data)
      File.open(filename, "w+") {|f| f.write(data) }
    end

    private :write

    ##
    # csv_array_write is a private delegate method to make it easier to test
    # CSV.open
    #
    # @api private
    def csv_array_write(filename, data)
      CSV.open(filename, "w+") do |csv|
        csv << ["LIFETIMES"]
        data.each do |value|
          to_write = [value]
          csv << to_write
        end
      end
    end

    private :csv_array_write

    ##
    # csv_hash_write is a private delegate method designed to handle hash input
    # and to make it easier to test CSV.open
    #
    # @api private
    def csv_hash_write(filename, data)
      CSV.open(filename, "w+") do |csv|
        csv << ["PR_NUM", "REPO", "LIFETIME" "MERGE_STATUS"]
        data.each do |key, value|
          row = [key, value[2], value[0], value[1]]
          csv << row
        end
      end
    end

    private :csv_hash_write
  end
end
