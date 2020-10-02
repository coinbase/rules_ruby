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
  # Expand all of the sources first
  metadata = expand_src_dirs(metadata)
  metadata = parse_require_paths(metadata)
  metadata = parse_gem_runtime_dependencies(metadata)
  metadata
end

def parse_require_paths(metadata)
  if metadata['require_paths'] == []
    metadata['srcs'].each do |f|
      metadata['require_paths'] << File.dirname(f) if File.basename(f, '.rb') == metadata['name']
    end
  end
  metadata
end

def _parse_gem_dependency(gem)
  's.add_runtime_dependency ' + gem
end

def parse_gem_runtime_dependencies(metadata)
  dependency_list = []
  if metadata['gem_runtime_dependencies'] != []
    metadata['gem_runtime_dependencies'].each do |gem|
      dependency_list.append(_parse_gem_dependency(gem))
    end
  end
  metadata['gem_runtime_dependencies'] = dependency_list.join("\n  ")
  metadata
end

def expand_src_dirs(metadata)
  # Files and required paths can include a directory which gemspec
  # cannot handle. This will convert directories to individual files
  srcs = metadata['raw_srcs']
  do_strip = metadata['do_strip']

  new_srcs = []
  dests = []
  srcs.each do |src|
    src_path = src['src_path']
    dest_path = src['dest_path']
    if File.directory?(src_path)
      Dir.glob("#{src_path}/**/*") do |f|
        # expand the directory, replacing each src path with its dest path
        if File.file?(f)
          g = f.gsub(src_path, dest_path)
          new_srcs << g
          if do_strip
            dests << g.sub(/^[^\/]+\//, '')
          else
            dests << g
          end
        end
      end
    elsif File.file?(src_path)
      new_srcs << dest_path
    end
  end
  metadata['srcs'] = new_srcs
  metadata['dests'] = dests
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
