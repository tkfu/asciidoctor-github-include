require 'asciidoctor/extensions' unless RUBY_ENGINE == 'opal'
require 'open-uri'

include ::Asciidoctor

class GithubPrivateUriIncludeProcessor < Extensions::IncludeProcessor
  def handles? target
    (target.start_with? 'https://raw.githubusercontent.com')
  end

  def process doc, reader, target, attributes
    tags = [attributes["tag"]] unless !attributes["tag"]
    tags = attributes["tags"].split(";") unless !attributes["tags"]
    begin
      doc.attr('github-access-token').nil? ? 
        content = (open target).readlines :
        content = (open target, "Authorization" => "token " + doc.attr('github-access-token')).readlines
    rescue
      warn %(asciidoctor: WARNING: Failed to retrieve GitHub URI #{target}. Did you set :github-access-token:?)
      content = "WARNING: Failed to retrieve GitHub URI link:#{target}[]"
    end
    content = process_tags(content, tags, target) unless !tags
    reader.push_include content, target, target, 1, attributes
    reader
  end

  # We need to process tags. This is a very naïve implementation to start with, and
  # only supports the case where there is exactly one opening and closing instance
  # of the tag in the file.
  #
  # text - the text to be processed, as an array of lines
  # tags - an array of tags to get
  # target - the URI of the object being fetched (only used to check the extension)
  def process_tags text, tags, target
    snipped_content = []

    # Asciidoctor provides a map of (file extension) => (opening and closing tags for
    # the file's circumfix comments). Use it to check for this case and get the right
    # suffix if needed.
    target_extension = target.slice (target.rindex '.'), target.length
    if (circ_cmt = CIRCUMFIX_COMMENTS[target_extension])
      circumfix_suffix = circ_cmt[:suffix]
    end

    tags.each do |tag|
      if circumfix_suffix
        tag_open = text.index{|line| line.chomp.end_with? %(tag::#{tag}[] #{circumfix_suffix})}
        tag_close = text.index{|line| line.chomp.end_with? %(end::#{tag}[] #{circumfix_suffix})}
      else
        tag_open = text.index{|line| line.chomp.end_with? %(tag::#{tag}[])}
        tag_close = text.index{|line| line.chomp.end_with? %(end::#{tag}[])}
      end
      snipped_content += text[tag_open+1..tag_close-1] unless (!tag_open || !tag_close)
    end
    snipped_content
  end

end

Extensions.register do
  include_processor GithubPrivateUriIncludeProcessor 
end
