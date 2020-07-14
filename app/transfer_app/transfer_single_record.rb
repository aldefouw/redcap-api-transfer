require_relative "library/transfer_records"

project_name = ARGV[0]
record_id = ARGV[1]

# ==== TRANSFERS SINGLE RECORD FROM A PROJECT ==== #
@transfer = TransferRecords.new(project_name: project_name)
@transfer.transfer_record_to_destination(record_id)