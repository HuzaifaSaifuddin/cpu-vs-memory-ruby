# STAGE 2 — "fixed the CPU problem" (but introduced a memory problem)
#
# Smart move: stop comparing every row to every row. Use a Hash keyed
# by order_id so lookups are O(1) -> whole scan is O(n). CPU problem solved.
#
# The mistake: to avoid re-reading the file later, we cache the FULL
# parsed row (every column) in the hash, not just the id. For every
# unique row we now hold a Hash of 5 fields + a ~450-byte notes string
# in memory, for the LIFETIME of the scan. That's the memory problem.

require "csv"

path = ARGV[0]
records = {} # order_id => full row hash (this is the problem)
duplicates = 0

CSV.foreach(path, headers: true) do |row|
  id = row["order_id"]
  if records.key?(id)
    duplicates += 1
  else
    records[id] = row.to_h # <- holding onto everything, not just the id
  end
end

puts "unique rows cached: #{records.size}, duplicate hits: #{duplicates}"
