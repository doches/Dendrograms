# Takes a .hrg (and an optional wordmap) and outputs a .dot
#
# Usage: ruby #{$0} file.hrg [file.wordmap] > file.dot

hrg = ARGV.shift
wordmap_f = ARGV.empty? ? nil : ARGV.shift

@map_names = true
@names = {}
IO.foreach(hrg.gsub("_best-dendro.hrg","-names.lut")) do |line|
  if not line =~ /virtual/
    virtual, real = *(line.strip.split(/\s+/))
    @names[virtual] = real
  end
end

@wordmap = nil
if not wordmap_f.nil?
  @wordmap = {}
  IO.foreach(wordmap_f) do |line|
    word, index = *(line.strip.split(/\s+/))
    @wordmap[index] = word
  end
end

@nodes = {}
def internal(index)
  if @nodes[index].nil?
    @nodes[index] = @nodes.size
    puts "\tINTERNAL#{@nodes[index]} [shape=point,label=\"\"];"
  end
  
  "INTERNAL#{@nodes[index]}"
end

@leaves = {}
def leaf(index)
  index = @names[index] if @map_names
  if @leaves[index].nil?
    @leaves[index] = @leaves.size
    label = index
    label = @wordmap[label] if not @wordmap.nil?
    puts "\tLEAF#{@leaves[index]} [shape=none,label=\"#{label}\"];"
  end
  
  "LEAF#{@leaves[index]}"
end

def node(type,index)
  if type == "D"
    return internal(index)
  else
    return leaf(index)
  end
end

puts "graph {"
IO.foreach(hrg) do |line|
  if line =~ /\[ (\d+) \] L= (\d+) \((D|G)\) R= (\d+) \((D|G)\)/
    dnode = node("D",$1)
    [[$3, $2], [$5, $4]].map { |pair| node(pair[0],pair[1]) }.each { |x| puts "\t#{dnode} -- #{x};" }
  end
end
puts "}"