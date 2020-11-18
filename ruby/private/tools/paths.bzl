def shorten_for_package(f, pkg):
    """Remove `pkg` from the beginning of `f.short_path`.
    If the result is a bare filename (with no further dir levels), return it.
    Otherwise, remove one more dir level.
    If that results in an empty path, return ".".
    """
    print("xxx shorten_for_package({}, {})".format(f.short_path, pkg))
    path = f.short_path
    if path.startswith(pkg+"/"):
        path = path[len(pkg)+1:]
    slash = path.find("/")
    if slash >= 0:
        print("xxx shorten_for_package [1] -> {}/{}".format(pkg, path[slash+1:]))
        return pkg+"/"+path[slash+1:]
    if f.is_directory:
        print("xxx shorten_for_package [2] -> {}".format(pkg))
        return pkg
    print("xxx shorten_for_package [3] -> {}".format(path))
    return path
