# Repository rules
load(
    "@coinbase_rules_ruby//ruby/private:dependencies.bzl",
    _rules_ruby_dependencies = "rules_ruby_dependencies",
)
load(
    "@coinbase_rules_ruby//ruby/private:sdk.bzl",
    _register_toolchains = "ruby_register_toolchains",
)

rules_ruby_dependencies = _rules_ruby_dependencies

ruby_register_toolchains = _register_toolchains
