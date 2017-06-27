Gem::Specification.new do |s|
  s.name = "abnftt"
  s.version = "0.1.0"
  s.summary = "RFC 5234+7405 ABNF to Treetop"
  s.description = %q{Shifty support for tools based on IETF's ABNF}
  s.author = "Carsten Bormann"
  s.email = "cabo@tzi.org"
  s.license = "MIT"
  s.homepage = "http://github.com/cabo/abnftt"
  s.has_rdoc = false
  s.files = Dir['lib/**/*.rb'] + %w(abnftt.gemspec) + Dir['bin/*']
  s.executables = Dir['bin/*'].map {|x| File.basename(x)}
  s.required_ruby_version = '>= 2.3'
  s.require_paths = ["lib"]
end
