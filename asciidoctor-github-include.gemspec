Gem::Specification.new do |s|
  s.name          = "asciidoctor-github-include"
  s.version       = "0.0.1"
  s.authors       = ["Jon Oster"]
  s.email         = ["jon@advancedtelematic.com"]
  s.description   = %q{Asciidoctor extension for including files from private GitHub repos}
  s.summary       = %q{Fetch files from private GitHub repos when you render your asciidoc files, using a GitHub private access token.}
  s.homepage      = "https://github.com/tkfu/asciidoctor-github-include"
  s.license       = "MIT"
  s.files         = "lib/asciidoctor-github-include.rb"
  s.add_runtime_dependency "asciidoctor", "~> 1.5", ">= 1.5.0"
end