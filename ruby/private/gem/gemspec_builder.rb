require 'json'
require 'optparse'

def parse_opts
  output_file = nil
  metadata_file = nil
  template_file = nil

  OptionParser.new do |opts|
    opts.on('--template [ARG]', 'Gemspec template file') do |v|
      template_file = v
    end
    opts.on('--output [ARG]', 'Output file') do |v|
      output_file = v
    end
    opts.on('--metadata [ARG]', 'Metadata file') do |v|
      metadata_file = v
    end
    opts.on('-h', '--help') do |_v|
      puts opts
      exit 0
    end
  end.parse!

  return output_file, metadata_file, template_file
end

def add_src_file(src, new_srcs, new_require_paths)
  if File.file?(src)
    new_srcs << src
    new_require_paths << File.dirname(src)
  end
end

def parse_metadata_srcs(metadata)
  # Files and required paths can include a directory which gemspec
  # cannot handle. This will convert directories to individual files
  # and update require_paths to include them..
  srcs = metadata["srcs"]
  new_require_paths = []
  new_srcs = []
  srcs.each do |src|
    if File.directory?(src)
      Dir.glob("#{src}/**/*") do |f|
        add_src_file(f, new_srcs, new_require_paths)
      end
    else
      add_src_file(src, new_srcs, new_require_paths)
    end
  end
  metadata["srcs"] = new_srcs
  metadata["require_paths"] = new_require_paths
  return metadata
end

def main
  output_file, metadata_file, template_file = parse_opts
  data = File.read(template_file)
  f = File.read(metadata_file)
  metadata = JSON.parse(f)

  metadata = parse_metadata_srcs metadata
  filtered_data = data

  metadata.each do |key, value|
    replace_val = "{#{key}}"
    filtered_data = filtered_data.gsub(replace_val, value.to_s)
  end

  File.open(output_file, "w") do |f|
    f.write(filtered_data)
  end
end

main if $PROGRAM_NAME == __FILE__
