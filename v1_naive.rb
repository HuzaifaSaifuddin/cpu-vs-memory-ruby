# STAGE 1 — "just find the duplicates" (naive, CPU problem)
#
# For every row, scan every OTHER row to see if the order_id repeats.
# That's O(n^2). CPU-bound: it never stops computing, barely allocates.

path = ARGV[0]
rows = File.readlines(path, chomp: true)[1..]

duplicates = []
rows.each_with_index do |row, i|
  id = row.split(",", 2).first
  rows.each_with_index do |other_row, j|
    next if i == j
    other_id = other_row.split(",", 2).first
    duplicates << id if id == other_id
  end
end

puts "rows: #{rows.size}, duplicate hits: #{duplicates.uniq.size}"
