require 'lib/cli'
require 'lib/Dendrogram'
require 'lib/Graph'

usage(
  "Takes a .dendro and outputs a clusterval-friendly yaml flat clustering",
  "ruby #{$0} file.dendro > file.yaml",
  1
)

dendro_f = ARGV.shift
graph_f = Dir.glob(File.join(File.dirname(dendro_f),"*.pairs"))[0]
wordmap_f = Dir.glob(File.join(File.dirname(dendro_f),"*.wordmap"))[0]

@graph = Graph.new(graph_f)
@dendrogram = Dendrogram.new(@graph, dendro_f)
@wordmap = {}
IO.foreach(wordmap_f) do |line|
  word,index = *(line.strip.split(/\s+/))
  @wordmap[index] = word
end

@min = @dendrogram.mean_theta

@clusters = {}
def identify_subtree_clusters(node)
  return @clusters[@clusters.size.to_s] = [@wordmap[node.to_s]] if node.is_a?(Fixnum)
  theta = node.connectedness(@graph)[0]
  if theta > @min
    @clusters[@clusters.size.to_s] = node.children.map { |x| @wordmap[x.to_s] }
  else
    return [identify_subtree_clusters(node.left), identify_subtree_clusters(node.right)]
  end
end

identify_subtree_clusters(@dendrogram.root)
puts @clusters.to_yaml
