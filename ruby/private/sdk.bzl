load(
    "@coinbase_rules_ruby//ruby/private/toolchains:ruby_runtime.bzl",
    _ruby_runtime = "ruby_runtime",
)

def ruby_register_toolchains(version = "host"):
    """Registers ruby toolchains in the WORKSPACE file."""

    _ruby_runtime(
        name = "org_ruby_lang_ruby_toolchain",
        version = version,
    )

    native.register_toolchains(
        "@org_ruby_lang_ruby_toolchain//:toolchain",
    )
