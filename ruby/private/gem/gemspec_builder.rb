# frozen_string_literal: true

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

  [output_file, metadata_file, template_file]
end

def parse_metadata(metadata)
  metadata = parse_require_paths(metadata)
  metadata = parse_metadata_srcs(metadata)
  metadata
end

def parse_require_paths(metadata)
  if metadata['require_paths'] == []
    expected_require_file = "#{metadata['name']}.rb"
    Dir.glob("**/#{expected_require_file}") do |f|
      metadata['require_paths'] << File.dirname(f)
    end
  end
  metadata
end

def parse_metadata_srcs(metadata)
  # Files and required paths can include a directory which gemspec
  # cannot handle. This will convert directories to individual files
  srcs = metadata['srcs']
  new_srcs = []
  srcs.each do |src|
    if File.directory?(src)
      Dir.glob("#{src}/**/*") do |_f|
        new_srcs << f if File.file?(f)
      end
    elsif File.file?(src)
      new_srcs << src
    end
  end
  metadata['srcs'] = new_srcs
  metadata
end

def main
  output_file, metadata_file, template_file = parse_opts
  data = File.read(template_file)
  m = File.read(metadata_file)
  metadata = JSON.parse(m)

  metadata = parse_metadata(metadata)
  filtered_data = data

  metadata.each do |key, value|
    replace_val = "{#{key}}"
    filtered_data = filtered_data.gsub(replace_val, value.to_s)
  end

  File.open(output_file, 'w') do |out_file|
    out_file.write(filtered_data)
  end
end

main if $PROGRAM_NAME == __FILE__
