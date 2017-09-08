Gem::Specification.new do |s|
  s.name        = 'sequel-bit_fields'
  s.version     = '1.3.0'
  s.date        = '2015-03-16'
  s.summary     = "A Sequel compatible version of common bit field technique."
  s.description = "Use this plugin to add flags/bits to your Sequel based models."
  s.authors     = ["Sascha Depold"]
  s.email       = 'sascha@depold.com'
  s.files       = ["lib/sequel/plugins/bit_fields.rb"]
  s.homepage    = 'https://github.com/sdepold/sequel-bit_fields'
  s.license     = "MIT"

  s.add_runtime_dependency "sequel", "~> 3.34"

  s.add_development_dependency "bundler"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "watchr"
end
