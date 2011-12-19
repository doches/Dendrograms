Description = "Takes a .dendro and outputs a .dot file"
Usage = "ruby #{$0} file.dendro > file.dot"
Num_Args = 1

if ARGV.size != Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

require 'lib/Dendrogram'
require 'lib/Graph'

dendro_f = ARGV.shift
graph_f = Dir.glob(File.join(File.dirname(dendro_f),"*.pairs"))[0]
wordmap_f = Dir.glob(File.join(File.dirname(dendro_f),"*.wordmap"))[0]
@min = ARGV.shift.to_f

@graph = Graph.new(graph_f)
@dendrogram = Dendrogram.new(@graph, dendro_f)
@wordmap = {}
IO.foreach(wordmap_f) do |line|
  word,index = *(line.strip.split(/\s+/))
  @wordmap[index] = word
end

puts @dendrogram.get_dot(@wordmap, @dendrogram.mean_theta)