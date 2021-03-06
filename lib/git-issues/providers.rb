require 'zlog'
require 'git-issues/login_helper'

# helper: quicly get all submodules
# http://www.natontesting.com/2010/06/30/how-to-get-the-submodules-of-a-ruby-module/
class Module
  def submodules
    constants.collect {|const_name| const_get(const_name)}.select {|const| const.class == Module}
  end

  def subclasses
    constants.collect {|const_name| const_get(const_name)}.select {|const| const.class == Class}
  end
end

# create the holder module for all providers
module RepoProvider; end
# get all predefined providers
require 'git-issues/providers/bitbucket'
require 'git-issues/providers/github'
require 'git-issues/providers/gitlab'

class RepoProviders
  attr_reader :providers
  def initialize
    @providers = RepoProvider.subclasses.map do |c|
        add_methods_to_provider(c)
      end
  end

  def map_urls_to_provider urls
    urls.map do |url|
      # get the first valid provider (or nil otherwise)
      @providers.map do |p|
        create_provider(p,url)
      end.compact.first
    end.compact
  end

  private 
  
  def create_provider p, url
    # break out if this is not a url for this provider
    repo = p.get_repo url
    return nil if repo.nil?
    # create the provider with the url
    pc = p.new
    pc.instance_variable_set(:@repo_url, url)
    pc.instance_variable_set(:@repo, repo)
    pc
  end

  def add_methods_to_provider c
    # get the base name of the provider
    name = c.name.sub(/.*::/,'').downcase
    # add simple fields
    ['repo_url', 'repo'].each do |arg|
      c.class_eval("def #{arg};@#{arg};end")
    end
    # add login helper
    c.class_eval <<-EOF
      def log; @log ||= Logging.logger[#{c}]; end
      def name; #{name.inspect} end
      include ::LoginHelper
      EOF
    c
  end
end