module Dendrograms

def check_flag(short,long)
  present = false
  [short,long].each do |opt|
    present = true if ARGV.include?(opt)
    ARGV.reject! { |x| x == opt }
  end
  return present
end

def check_opt(short,long,default)
	value = default
	[short, long].each do |opt|
		if ARGV.include?(opt)
			index = ARGV.index(opt)
			value = ARGV[index+1]
			ARGV.delete_at(index)
			ARGV.delete_at(index)
			break
		end
	end
	return value
end

def usage(description, usage, args)
  if ARGV.size != args
    STDERR.puts description
    STDERR.puts " "
    STDERR.puts "Usage: #{usage}"
    exit(1)
  end
end

end