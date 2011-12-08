Description = "Re-implementation, basically, of Clauset's consensusHRG tool\nTakes a .dendro file, a .pairs file, and a wordmap; outputs a consensus hierarchy"
Usage = "ruby #{$0} file.dendro file.pairs file.wordmap > file.consensus.dot"
Num_Args = 3

if ARGV.size != Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

require 'lib/Graph'
require 'lib/Dendrogram'

dendro_file = ARGV.shift
graph_file = ARGV.shift
wordmap_file = ARGV.shift
wordmap = {}
IO.foreach(wordmap_file) do |line|
  word,index = *(line.strip.split(/\s+/))
  wordmap[index] = word
end
tree_file = dendro_file.gsub(".dendro",".ctree")

graph = Graph.new(graph_file)
dendrogram = Dendrogram.new(graph, dendro_file)

samples = 100
spread = 100
clusters = {}
sample_index = 0
STDERR.puts ["MCMC STEPS","LIKELIHOOD"].join("\t")
while sample_index < samples
  spread.times { dendrogram.sample! }
  dendrogram.clusters.each do |cluster|
    cluster = cluster.reject { |x| x.nil? }.sort
    clusters[cluster.join("_")] ||= 0
    clusters[cluster.sort.join("_")] += 1
  end
  STDERR.puts [dendrogram.mcmc_steps, dendrogram.likelihood].join("\t")

  sample_index += 1
end

keep = clusters.map { |k,v| [k,v] }.reject { |pair| pair[1] < samples/2 }.map { |pair| pair[0].split("_").map { |x| wordmap[x] } }.sort { |b,a| a.size <=> b.size }

while keep.size > 1
  child = nil
  keep.each do |a|
    (keep-a).each do |b|
      if a!=b and (a&b).size == a.size
        # B includes a
        child = [a,b]
      end
    end
  end
  if child.nil?
    break
  end
  keep = keep-child
  child[1] = child[1]-child[0]
  child[1].push child[0]
  keep.push child[1]
end

@levels = {}
def node(cluster)
  if @levels[cluster].nil?
    @levels[cluster] = @levels.size
    puts "\tINTERNAL#{@levels[cluster]} [shape=point, label=\"\"];"
  end
  return @levels[cluster]
end
@leaves = {}
def leaf(cluster)
  if @leaves[cluster].nil?
    @leaves[cluster] = @leaves.size
    puts "\tLEAF#{@leaves[cluster]} [shape=none, label=\"#{cluster}\"];"
  end
  return @leaves[cluster]
end
def print(list)
  list.each do |cluster|
    if cluster.is_a?(Array)
      puts "\tINTERNAL#{node(list)} -- INTERNAL#{node(cluster)};"
      print(cluster)
    else
      puts "\tINTERNAL#{node(list)} -- LEAF#{leaf(cluster)};"
    end
  end
end
puts "graph {"
print(keep)
puts "}"