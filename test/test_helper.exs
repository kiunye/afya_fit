ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(AfyaFit.Repo, :manual)
ExUnit.start(formatters: [ExUnit.CLIFormatter, JUnitFormatter])

# make the file land in the project root (same dir mix is run from)
# optional
:ok = File.mkdir_p!("test-results")
Application.put_env(:junit_formatter, :report_dir, ".")
Application.put_env(:junit_formatter, :report_file, "test-results.xml")
