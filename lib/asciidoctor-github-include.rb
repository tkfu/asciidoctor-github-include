require 'asciidoctor/extensions' unless RUBY_ENGINE == 'opal'
require 'open-uri'

include ::Asciidoctor

class GithubPrivateUriIncludeProcessor < Extensions::IncludeProcessor
  def handles? target
    (target.start_with? 'https://raw.githubusercontent.com')
  end

  def process doc, reader, target, attributes
    begin
      doc.attr('github-access-token').nil? ? 
        content = (open target).readlines :
        content = (open target, "Authorization" => "token " + doc.attr('github-access-token')).readlines
    rescue
      warn %(asciidoctor: WARNING: Failed to retrieve GitHub URI #{target}. Did you set :github-access-token:?)
      content = "WARNING: Failed to retrieve GitHub URI link:#{target}[]"
    end
    reader.push_include content, target, target, 1, attributes
    reader
  end
end

Extensions.register do
  include_processor GithubPrivateUriIncludeProcessor 
end

