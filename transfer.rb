require "#{Dir.getwd}/library/transfer_files"

options = {}

@transfer = TransferFiles.new(options)
@transfer.run