def strip_short_path(path, strip_paths):
    """ Given a short_path string will iterate over the
    list of strip_paths and remove any matches returning a
    new path string with no leading slash.
    """
    if not strip_paths:
        return path

    for strip_path in strip_paths:
        if path.startswith(strip_path):
            return path.replace(strip_path, "").lstrip("/")
    return path
