# Multi-db Configuration
#
# Automatic connection switching (Rails' DatabaseSelector middleware): GET and HEAD requests read from the replica
# (the `primary_replica` database in config/database.yml, the `postgres-replica` service), every other request
# (POST, PUT, PATCH, DELETE) runs on the primary. A write attempted while reading raises ActiveRecord::ReadOnlyError.
#
# Rails' default resolver context (Resolver::Session) remembers each client's last write in the session, to keep
# its reads on the primary for `delay` afterwards. This API has no session store (nor cookies on its clients), so
# this context keeps no state: every read goes to the replica, however recent the client's last write.
class StatelessDatabaseSelectorContext
  def self.call(_request)
    new
  end

  # Never a recent write, so reads always go to the replica.
  def last_write_timestamp
    Time.at(0)
  end

  def update_last_write_timestamp
  end

  def save(_response)
  end
end

Rails.application.configure do
  config.active_record.database_selector = {} # no `delay`: without a last write to compare against, it's unused
  config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  config.active_record.database_resolver_context = StatelessDatabaseSelectorContext
end
