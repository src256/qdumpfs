#!/usr/bin/env ruby

def find_version
  file = File.expand_path(File.dirname(__FILE__) + '/lib/qdumpfs/version.rb')
  File.readlines(file).each do |line|
    #  puts line
    if line =~ /VERSION\s*=\s*['"]([^'"]+)['"]/
      return $1
    end
  end
  return nil
end

def run_cmd(cmd)
  puts cmd
  system(cmd)
end

version = find_version
if version.nil?
  puts "Version not found"
  exit(1)
end


tagname = "v#{version}"
cmd = "git tag #{tagname}"
run_cmd(cmd)
cmd = "git push origin #{tagname}"
run_cmd(cmd)

#
