require 'asciidoctor/extensions' unless RUBY_ENGINE == 'opal'
require 'open-uri'

include ::Asciidoctor

class GithubPrivateUriIncludeProcessor < Extensions::IncludeProcessor
  def handles? target
    (target.start_with? 'https://raw.githubusercontent.com')
  end

  def process doc, reader, target, attributes

    tags  = [attributes["tag"]] if attributes.key? "tag" unless attributes["tag"] == ""
    tags  = attributes["tags"].split(DataDelimiterRx) if attributes.key? "tags" unless attributes["tags"] == ""
    lines = attributes["lines"] unless attributes["lines"] == ""

    # Fetch the file to be included
    begin
      doc.attr('github-access-token').nil? ? 
        content = (open target).readlines :
        content = (open target, "Authorization" => "token " + doc.attr('github-access-token')).readlines
    rescue
      warn %(asciidoctor: WARNING: Failed to retrieve GitHub URI #{target}. Did you set :github-access-token:?)
      content = "WARNING: Failed to retrieve GitHub URI link:#{target}[]"
      return reader.push_include content, target, target, 1, attributes
    end

    # process the lines and tags attributes
    content = process_line_selection(content, lines, target) if lines
    content = process_tags(content, tags, target) if tags unless lines

    # push the lines onto the reader and return it
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
      if (!tag_open && !tag_close)
        warn %(asciidoctor: WARNING: Tag #{tag} not found in included GitHub URI #{target}.)
      elsif (!tag_open && tag_close)
        warn %(asciidoctor: WARNING: Tag #{tag} not found in included GitHub URI #{target}, but end::[] tag was found.)
      elsif (tag_open && !tag_close)
        warn %(asciidoctor: WARNING: Closing tag for tag #{tag} not found in included GitHub URI #{target}.)
      end

      snipped_content += text[tag_open+1..tag_close-1] unless (!tag_open || !tag_close)
    end
    snipped_content
  end

  def process_line_selection text, lines, target
    snipped_content = []
    selected_lines = []

    lines.split(DataDelimiterRx).each do |linedef|
      if linedef.include?('..')
        from, to = linedef.split('..', 2).map {|it| it.to_i }
        to = text.length if to == -1 # -1 as a closing length means end of file
        selected_lines.concat ::Range.new(from, to).to_a
      else
        selected_lines << linedef.to_i
      end
    end
    selected_lines.sort.uniq.each do |i|
      snipped_content << text[i-1]
    end
    snipped_content
  end

end

Extensions.register do
  include_processor GithubPrivateUriIncludeProcessor 
end
