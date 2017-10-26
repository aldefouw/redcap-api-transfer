require "#{Dir.getwd}/library/transfer_records"

options = { processes: 10 }

@transfer = TransferRecords.new(options)
@transfer.run