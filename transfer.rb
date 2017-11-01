require "#{Dir.getwd}/library/transfer_records"

@transfer = TransferRecords.new(processes: 8)
@transfer.run