Description = "Takes a .hrg and a -names.lut and outputs a .dendro"
Usage = "ruby #{$0} file.hrg file.lut > file.dendro"
Num_Args = 2

if ARGV.size != Num_Args
  STDERR.puts Description
  STDERR.puts " "
  STDERR.puts "Usage: #{Usage}"
  exit(1)
end

hrg_f = ARGV.shift
lut_f = ARGV.shift
names = nil
IO.foreach(lut_f) do |line|
  if names.nil?
    names = {}
  else
    virtual, real = *(line.strip.split(/\s+/))
    names[virtual] = real
  end
end

#[ 0 ] L= 46 (D) R= 29 (D) p= 0 e= 0 n= 49
IO.foreach(hrg_f) do |line|
  if line =~ /\[ (\d+) \] L= (\d+) \(([D|G])\) R= (\d+) \(([D|G])\)/
    index, left, left_type, right, right_type = $1, $2, $3, $4, $5
    left = names[left] if left_type == "G"
    right = names[right] if right_type == "G"
    puts "#{index}\t#{left} (#{left_type})\t#{right} (#{right_type})"
  end
end