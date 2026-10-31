# STAGE 3 — fixes BOTH problems
#
# Same O(1) lookup trick as stage 2 (so CPU stays fast)...
# ...but we only ever keep the order_id in memory, never the full row,
# and we stream the file line-by-line instead of loading it all at once.
# Memory footprint is now proportional to UNIQUE IDS, not file size.

require "set"

path = ARGV[0]
seen = Set.new
duplicates = 0

File.foreach(path, chomp: true).with_index do |line, i|
  next if i == 0 # header
  id = line.split(",", 2).first
  if seen.include?(id)
    duplicates += 1
  else
    seen << id
  end
end

puts "unique ids tracked: #{seen.size}, duplicate hits: #{duplicates}"
