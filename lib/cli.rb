def check_flag(short,long)
  present = false
  [short,long].each do |opt|
    present = true if ARGV.include?(opt)
    ARGV.reject! { |x| x == opt }
  end
  return present
end