require "#{Dir.getwd}/library/transfer_records"

options = { threads: 10 }

@transfer = TransferRecords.new(options)
@transfer.run