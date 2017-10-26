require "#{Dir.getwd}/library/transfer_records"

options = { threads: 1 }

@transfer = TransferRecords.new(options)
@transfer.run