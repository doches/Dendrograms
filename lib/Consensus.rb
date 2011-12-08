class ConsensusNode
  attr_reader :index
  @@index = 0
  def initialize(children)
    @children = children
    @index = @@index
    @@index += 1
    @leaves = children.dup
  end
  
  @@leaves = {}
  def ConsensusNode.leaf(leaf)
    @@leaves[leaf] ||= @@leaves.size
    return @@leaves[leaf]
  end
  
  def children
    @children.map { |x| x.is_a?(ConsensusNode) ? x.children : x }.flatten
  end
  
  def add_child(node)
    @children = @children - node.children
    @children.push node
  end
  
  def contains(set)
    (@leaves & set).size == set.size
  end
  
  def size
    @leaves.size
  end
  
  def to_dot(wordmap)
    puts "\tINTERNAL_#{@index} [shape=point, label=\"\"];"
    @children.each do |child|
      if child.is_a?(ConsensusNode)
        puts "\tINTERNAL_#{@index} -- INTERNAL_#{child.index};"
        child.to_dot(wordmap)
      else
        puts "\tLEAF_#{ConsensusNode.leaf(child)} [shape=none, label=\"#{wordmap[child.to_s]}\"];"
        puts "\tINTERNAL_#{@index} -- LEAF_#{ConsensusNode.leaf(child)};"
      end
    end
  end
end