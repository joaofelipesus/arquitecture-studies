# Traces every request (Rack, controllers, views, Active Record and the SQL sent by pg) and exports them
# over OTLP to Tempo (see docker-compose.yml). Only enabled when an OTLP endpoint is set, and never in tests:
# `bin/rails test` run inside the app container inherits the endpoint and would export the test requests.
if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present? && !Rails.env.test?
  OpenTelemetry::SDK.configure do |c|
    c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "books-library")
    # Tells the app instances apart (app, app2, ...); compose sets the container hostname.
    c.resource = OpenTelemetry::SDK::Resources::Resource.create(
      OpenTelemetry::SemanticConventions::Resource::SERVICE_INSTANCE_ID => Socket.gethostname
    )
    # Skip the health checks Docker runs every 5 seconds.
    c.use_all("OpenTelemetry::Instrumentation::Rack" => { untraced_endpoints: [ "/up" ] })
  end
end
