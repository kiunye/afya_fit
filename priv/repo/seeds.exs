# Demo data for development: organisations in every billing state, with people,
# plans, tasks, progress, events, invoices and payments to look at.
#
#     mix run priv/repo/seeds.exs
#
# Safe to run again. It refuses to run in production. See docs/dev.md.

if Mix.env() == :prod do
  raise "Demo seeds are for development only."
end

%{admin: admin, organizations: organizations} = AfyaFit.Dev.Seeds.run()

IO.puts("\nDemo data ready. Every password is: #{AfyaFit.Dev.Seeds.password()}\n")
IO.puts("  Platform admin  #{admin.email}\n")

for org <- organizations do
  IO.puts("  #{org.name}: #{org.state}")
  IO.puts("    owner    #{org.owner}")
  for email <- org.trainers, do: IO.puts("    trainer  #{email}")
  for email <- Enum.take(org.clients, 2), do: IO.puts("    client   #{email}")
  IO.puts("")
end
