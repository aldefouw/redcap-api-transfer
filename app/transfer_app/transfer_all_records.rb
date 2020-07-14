require_relative "library/transfer_records"

project_name = ARGV[0]

# ==== TRANSFERS ALL RECORDS FROM A PROJECT ==== #
@transfer = TransferRecords.new(project_name: project_name)
@transfer.run