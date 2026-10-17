class ApplicationController < ActionController::API
  private
    # GET requests read from the replica (config/initializers/multi_db.rb). Actions that cache what they read use
    # `around_action :read_from_primary` instead: the replica can lag a little behind a write, and a page built from
    # it right after one would stay cached, stale, until it expires.
    def read_from_primary(&)
      ActiveRecord::Base.connected_to(role: :writing, prevent_writes: true, &)
    end
end
