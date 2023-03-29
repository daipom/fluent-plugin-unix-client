lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name    = "fluent-plugin-unix-client"
  spec.version = "1.0.0"
  spec.authors = ["daipom"]
  spec.email   = ["reangoapyththeorem@gmail.com"]

  spec.summary       = %q{Fluentd Input plugin to receive data from UNIX domain socket. This is a client version of the default `unix` input plugin.}
  spec.homepage      = "https://github.com/daipom/fluent-plugin-unix-client"
  spec.license       = "Apache-2.0"

  test_files, files  = `git ls-files -z`.split("\x0").partition do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.files         = files
  spec.executables   = files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = test_files
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "test-unit", "~> 3.3"
  spec.add_runtime_dependency "fluentd", [">= 0.14.10", "< 2"]
end
