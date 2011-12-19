#!/usr/bin/ruby
Description = "Re-implementation, basically, of Clauset's consensusHRG tool\nTakes a .dendro file, a .pairs file, and a wordmap; outputs a consensus hierarchy"
Usage = "ruby #{$0} file.dendro file.pairs file.wordmap > file.consensus.dot"
Num_Args = 3

require 'lib/Graph'
require 'lib/Dendrogram'
require 'lib/Consensus'
require 'lib/cli'

verbose = check_flag("-v","--verbose")
samples = check_opt("-s","--samples","300").to_i
spread = check_opt("-S","--spread","100").to_i

if ARGV.size != Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

STDERR.puts "#{samples} samples with a spread of #{spread} \n  -> #{samples*spread} resamples"

dendro_file = ARGV.shift
graph_file = ARGV.shift
wordmap_file = ARGV.shift
@wordmap = {}
IO.foreach(wordmap_file) do |line|
  word,index = *(line.strip.split(/\s+/))
  @wordmap[index] = word
end

graph = Graph.new(graph_file)
dendrogram = Dendrogram.new(graph, dendro_file)

clusters = {}
sample_index = 0
STDERR.puts ["MCMC STEPS","LIKELIHOOD","TIME"].join("\t") if verbose
start = Time.now.to_i
while sample_index < samples
  spread.times { dendrogram.sample! }
  dclusters = dendrogram.clusters.map { |cluster| cluster.reject { |x| x.nil? }.sort.join("_") }.uniq
  dclusters.each do |cluster|
    clusters[cluster] ||= 0
    clusters[cluster] += 1
  end
  STDERR.puts [dendrogram.mcmc_steps, dendrogram.likelihood,"#{Time.now.to_i-start}s"].join("\t") if verbose

  sample_index += 1
end

clusters.reject! { |k,v| v <= samples/2.0 }
#clusters.map { |k,v| [k,v] }.sort { |a,b| a[1] <=> b[1] }.each { |k,v| STDERR.puts "#{v}:\t#{k.gsub('_',", ")}" }

keep = clusters.map { |pair| pair[0].split("_").map { |x| x.to_i } }.sort { |b,a| a.size <=> b.size }
keep.unshift keep.flatten.uniq
keep.uniq!

# keep.each do |x|
#   STDERR.puts "  #{x.map { |y| @wordmap[y.to_s] }.inspect}"
# end

hnodes = [ConsensusNode.new(keep.shift)]
while keep.size > 0
  STDERR.puts keep.size
  cluster = keep.shift
  lca = hnodes.reject { |x| not x.contains(cluster) }.sort { |a,b| a.size <=> b.size }[0]
  new_node = ConsensusNode.new(cluster)
  lca.add_child(new_node)
  hnodes.push new_node
end

puts "graph {"
hnodes[0].to_dot(@wordmap)
puts "}"
