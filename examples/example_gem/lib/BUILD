package(default_visibility = ["//:__subpackages__"])

load(
    "@coinbase_rules_ruby//ruby:defs.bzl",
    "rb_library",
)

rb_library(
    name = "example_gem",
    srcs = ["example_gem.rb"],
    deps = ["//lib/foo:default_library"],
)
