package(default_visibility = ["//:__subpackages__"])

load(
    "@coinbase_rules_ruby//ruby:defs.bzl",
    "rb_binary",
    "rb_test",
)

rb_binary(
    name = "server",
    srcs = glob(
        include = [
            "app/**/*",
            "config/**/*",
            "bin/*",
            "config.ru",
        ],
    ),
    main = ":bin/rails",
    deps = [
        "@bundle//:rails",
    ],
)
