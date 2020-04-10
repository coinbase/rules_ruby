package(default_visibility = ["//:__subpackages__"])

load(
    "@coinbase_rules_ruby//ruby:defs.bzl",
    "rb_gem",
)

rb_gem(
    name = "example_gem",
    authors = ["Coinbase"],
    gem_name = "example_gem",
    version = "0.1.0",
    deps = [
        "//lib:example_gem",
    ],
)
