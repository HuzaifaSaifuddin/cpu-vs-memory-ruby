# Generates a fake orders.csv: order_id,customer,product,price,notes
# ~5% of rows are intentional duplicate order_ids (simulates a real
# data quality issue you'd be scanning for).

n = (ARGV[0] || 50_000).to_i
path = ARGV[1] || "orders.csv"

notes_filler = "Customer requested gift wrap and delivery instructions left at the gate. " * 6

File.open(path, "w") do |f|
  f.puts "order_id,customer,product,price,notes"
  seen_ids = []

  n.times do |i|
    id = if !seen_ids.empty? && rand < 0.05
      seen_ids.sample # reuse an old id -> duplicate
    else
      new_id = "ORD-#{i}"
      seen_ids << new_id
      new_id
    end

    f.puts "#{id},customer_#{i},product_#{i % 500},#{(rand * 100).round(2)},#{notes_filler}"
  end
end

puts "wrote #{n} rows to #{path} (#{File.size(path) / 1024 / 1024}MB)"
