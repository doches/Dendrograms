#!/usr/bin/ruby
Description = "Reads in a dendrogram; outputs a .dot"
Usage = "ruby #{$0} file.pairs file.dendro > file.dot"
Num_Args = 2

require 'lib/Graph'
require 'lib/Dendrogram'
require 'lib/cli'

verbose = check_flag("-v","--verbose")

if ARGV.size < Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

pairs_file = ARGV.shift
dendro_file = ARGV.shift

graph = Graph.new(pairs_file)
dendrogram = Dendrogram.new(graph, dendro_file)

puts dendrogram.get_dot()