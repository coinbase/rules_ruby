def dest_path(f, pkg):
    result = f.short_path
    if pkg and result.startswith(pkg):
        result = result[1+len(pkg):]
    return result
