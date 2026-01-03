ExUnit.start()

# Ensure the application is started
{:ok, _} = Application.ensure_all_started(:kpd)

# Set up sandbox mode for tests
Ecto.Adapters.SQL.Sandbox.mode(KPD.Repo, :manual)

# Seed the test database with data
# We need to checkout the repo first since we're outside a test context
:ok = Ecto.Adapters.SQL.Sandbox.checkout(KPD.Repo)
Ecto.Adapters.SQL.Sandbox.mode(KPD.Repo, :auto)

# Clear any existing data and seed fresh
KPD.TestSeeds.reseed!()

# Switch back to manual mode for tests
Ecto.Adapters.SQL.Sandbox.mode(KPD.Repo, :manual)
