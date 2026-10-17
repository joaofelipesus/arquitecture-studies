class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Writes go to the primary, reads inside ActiveRecord::Base.connected_to(role: :reading) to the replica: GET
  # requests, through config/initializers/multi_db.rb.
  connects_to database: { writing: :primary, reading: :primary_replica }
end
