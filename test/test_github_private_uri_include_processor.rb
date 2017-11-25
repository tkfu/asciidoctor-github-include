# encoding: UTF-8
require_relative 'test-helper'

# Borrowed from AsciiDoctor's tests. MIT licensed;
#
# Copyright (C) 2012-2017 Dan Allen, Ryan Waldron and the Asciidoctor Project

class ExtensionTest < Minitest::Test

  context 'Errors' do

    test 'missing file referenced by include directive is replaced by warning' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/no-such-file.adoc[]

trailing content
      EOS

      begin
        doc, warnings = redirect_streams do |_, err|
          [(document_from_string input), err.string]
        end
        assert_equal 2, doc.blocks.size
        assert_equal ['Failed to retrieve GitHub URI link:https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/no-such-file.adoc[]'], doc.blocks[0].lines
        assert_equal ['trailing content'], doc.blocks[1].lines
        assert_includes warnings, 'Failed to retrieve GitHub URI'
      rescue
        flunk 'include directive should not raise exception on missing file'
      end
    end
  end

  context 'LineSelection' do

    test 'include directive supports line selection' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[lines=1;3..4;6..-1]
      EOS

      output = render_embedded_string input
      assert_match(/first line/, output)
      refute_match(/second line/, output)
      assert_match(/third line/, output)
      assert_match(/fourth line/, output)
      refute_match(/fifth line/, output)
      assert_match(/sixth line/, output)
      assert_match(/seventh line/, output)
      assert_match(/eighth line/, output)
      assert_match(/last line of included content/, output)
    end

    test 'include directive supports line selection using quoted attribute value' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[lines="1, 3..4 , 6 .. -1"]
      EOS

      output = render_embedded_string input
      assert_match(/first line/, output)
      refute_match(/second line/, output)
      assert_match(/third line/, output)
      assert_match(/fourth line/, output)
      refute_match(/fifth line/, output)
      assert_match(/sixth line/, output)
      assert_match(/seventh line/, output)
      assert_match(/eighth line/, output)
      assert_match(/last line of included content/, output)
    end

    test 'include directive ignores empty lines attribute' do
      input = <<-EOS
++++
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[lines=]
++++
      EOS

      output = render_embedded_string input
      assert_includes output, 'first line of included content'
      assert_includes output, 'last line of included content'
    end

    test 'lines attribute takes precedence over tags attribute in include directive' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[lines=1, tags=snippetA;snippetB]
      EOS

      output = render_embedded_string input
      assert_match(/first line of included content/, output)
      refute_match(/snippetA content/, output)
      refute_match(/snippetB content/, output)
    end
  end


  context 'TagSelection' do
  
    test 'include directive supports tagged selection' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[tag=snippetA]
      EOS

      output = render_embedded_string input
      assert_match(/snippetA content/, output)
      refute_match(/snippetB content/, output)
      refute_match(/non-tagged content/, output)
      refute_match(/included content/, output)
    end

    test 'include directive supports multiple tagged selection' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[tags=snippetA;snippetB]
      EOS

      output = render_embedded_string input
      assert_match(/snippetA content/, output)
      assert_match(/snippetB content/, output)
      refute_match(/non-tagged content/, output)
      refute_match(/included content/, output)
    end

    test 'include directive supports tagged selection in language that uses circumfix comments' do
      {
        'include-file.xml' => '<snippet>content</snippet>',
        'include-file.ml' => 'let s = SS.empty;;'
      }.each do |filename, expect|
        input = <<-EOS
[source,xml,indent=0]
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/#{filename}[tag=snippet]
----
        EOS

        doc = document_from_string input
        assert_equal expect, doc.blocks[0].source
      end
    end

    test 'include directive does not select lines with tag directives inside tagged selection' do
      input = <<-EOS
++++
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[tags=snippet]
++++
      EOS

      output = render_embedded_string input
      expect = %(snippetA content

non-tagged content

snippetB content)
      assert_equal expect, output
    end


    test 'should warn if tag is not found in include file' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[tag=snippetZ]
      EOS

      old_stderr = $stderr
      $stderr = StringIO.new
      begin
        render_embedded_string input
        warning = $stderr.tap(&:rewind).read
        refute_nil warning
        assert_match(/WARNING.*snippetZ/, warning)
      ensure
        $stderr = old_stderr
      end
    end

    test 'should warn if end tag in included file is mismatched' do
      input = <<-EOS
++++
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/mismatched-end-tag.adoc[tags=a;b]
++++
      EOS

      result, warnings = redirect_streams do |out, err|
        [(render_embedded_string input), err.string]
      end
      assert_equal %(a\nb), result
      refute_nil warnings
      assert_match(/WARNING: .*end tag/, warnings)
    end

    test 'include directive ignores tags attribute when empty' do
      ['tag', 'tags'].each do |attr_name|
        input = <<-EOS
++++
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.xml[#{attr_name}=]
++++
        EOS

        output = render_embedded_string input
        assert_match(/(?:tag|end)::/, output, 2)
      end
    end
  end
end
=begin
  context 'WildcardTagSelection' do

    test 'include directive skips lines marked with negated tags' do
      input = <<-EOS
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class-enclosed.rb[tags=all;!bark]
----
      EOS

      output = render_embedded_string input
      expected = %(class Dog
  def initialize breed
  @breed = breed
  end
end)
      assert_includes output, expected
    end

    test 'include directive takes all lines without tag directives when value is double asterisk' do
      input = <<-EOS
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class.rb[tags=**]
----
      EOS

      output = render_embedded_string input
      expected = %(class Dog
  def initialize breed
  @breed = breed
  end

  def bark
  if @breed == 'beagle'
    'woof woof woof woof woof'
  else
    'woof woof'
  end
  end
end)
      assert_includes output, expected
    end

    test 'include directive takes all lines except negated tags when value contains double asterisk' do
      input = <<-EOS
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class.rb[tags=**;!bark]
----
      EOS

      output = render_embedded_string input
      expected = %(class Dog
  def initialize breed
  @breed = breed
  end
end)
      assert_includes output, expected
    end

    test 'include directive selects lines for all tags when value of tags attribute is wildcard' do
      input = <<-EOS
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class-enclosed.rb[tags=*]
----
      EOS

      output = render_embedded_string input
      expected = %(class Dog
  def initialize breed
  @breed = breed
  end

  def bark
  if @breed == 'beagle'
    'woof woof woof woof woof'
  else
    'woof woof'
  end
  end
end)
      assert_includes output, expected
    end

    test 'include directive selects lines for all tags except exclusions when value of tags attribute is wildcard' do
      input = <<-EOS
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class-enclosed.rb[tags=*;!init]
----
      EOS

      output = render_embedded_string input
      expected = %(class Dog

  def bark
  if @breed == 'beagle'
    'woof woof woof woof woof'
  else
    'woof woof'
  end
  end
end)
      assert_includes output, expected
    end

    test 'include directive skips lines all tagged lines when value of tags attribute is negated wildcard' do
      input = <<-EOS
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class.rb[tags=!*]
----
      EOS

      output = render_embedded_string input
      expected = %(class Dog
end)
      assert_includes output, expected
    end

    test 'include directive selects specified tagged lines and ignores the other tag directives' do
      input = <<-EOS
[indent=0]
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/tagged-class.rb[tags=bark;!bark-other]
----
      EOS

      output = render_embedded_string input
      expected = %(def bark
  if @breed == 'beagle'
  'woof woof woof woof woof'
  end
end)
      assert_includes output, expected
    end
  end

=begin
    test 'lines attribute takes precedence over tags attribute in include directive' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/include-file.asciidoc[lines=1, tags=snippetA;snippetB]
      EOS

      output = render_embedded_string input
      assert_match(/first line of included content/, output)
      refute_match(/snippetA content/, output)
      refute_match(/snippetB content/, output)
    end

    test 'indent of included file can be reset to size of indent attribute' do
      input = <<-EOS
[source, xml]
----
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/basic-docinfo.xml[lines=2..3, indent=0]
----
      EOS

      output = render_embedded_string input
      result = xmlnodes_at_xpath('//pre', output, 1).text
      assert_equal "<year>2013</year>\n<holder>Acme™, Inc.</holder>", result
    end

    test 'leveloffset attribute entries should be added to content if leveloffset attribute is specified' do
      input = <<-EOS
include::https://raw.githubusercontent.com/asciidoctor/asciidoctor/master/test/fixtures/master.adoc[]
      EOS

      expected = <<-EOS.chomp.split(::Asciidoctor::LF)
= Master Document

preamble

:leveloffset: +1

= Chapter A

content

:leveloffset!:
      EOS

      document = Asciidoctor.load input, :safe => :safe, :base_dir => DIRNAME, :parse => false
      assert_equal expected, document.reader.read_lines
    end

    test 'attributes are substituted in target of include directive' do
      input = <<-EOS
:fixturesdir: fixtures
:ext: asciidoc

include::{fixturesdir}/include-file.{ext}[]
      EOS

      doc = document_from_string input, :safe => :safe, :base_dir => DIRNAME
      output = doc.render
      assert_match(/included content/, output)
    end

=end

