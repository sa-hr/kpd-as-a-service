ExUnit.start()

# Ensure the application is started
{:ok, _} = Application.ensure_all_started(:kpd_as_a_service)

# Set up sandbox mode for tests
Ecto.Adapters.SQL.Sandbox.mode(KpdAsAService.Repo, :manual)

# Seed the test database with data
# We need to checkout the repo first since we're outside a test context
:ok = Ecto.Adapters.SQL.Sandbox.checkout(KpdAsAService.Repo)
Ecto.Adapters.SQL.Sandbox.mode(KpdAsAService.Repo, :auto)

# Clear any existing data and seed fresh
KpdAsAService.TestSeeds.reseed!()

# Switch back to manual mode for tests
Ecto.Adapters.SQL.Sandbox.mode(KpdAsAService.Repo, :manual)
