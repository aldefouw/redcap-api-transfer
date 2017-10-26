require "#{Dir.getwd}/library/transfer_records"

options = { processes: 8 }

@transfer = TransferRecords.new(options)
@transfer.run