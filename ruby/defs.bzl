load(
    "@coinbase_rules_ruby//ruby/private:toolchain.bzl",
    _toolchain = "ruby_toolchain",
)
load(
    "@coinbase_rules_ruby//ruby/private:library.bzl",
    _library = "rb_library",
)
load(
    "@coinbase_rules_ruby//ruby/private:binary.bzl",
    _binary = "rb_binary",
    _test = "rb_test",
)
load(
    "@coinbase_rules_ruby//ruby/private:bundle.bzl",
    _rb_bundle = "rb_bundle",
)
load(
    "@coinbase_rules_ruby//ruby/private:rspec.bzl",
    _rb_rspec = "rb_rspec",
    _rb_rspec_test = "rb_rspec_test",
)

load(
    "@coinbase_rules_ruby//ruby/private/rubocop:def.bzl",
    _rubocop = "rubocop",
)

ruby_toolchain = _toolchain
rb_library = _library
rb_binary = _binary
rb_test = _test
rb_rspec_test = _rb_rspec_test
rb_rspec = _rb_rspec
rubocop = _rubocop
bundle_install = _rb_bundle
rb_bundle = _rb_bundle
