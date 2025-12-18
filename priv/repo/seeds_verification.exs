# Script to verify schema relationships and detailed structure
alias AfyaFit.Repo
alias AfyaFit.Organizations.Organization
alias AfyaFit.Accounts.User
alias AfyaFit.Workouts.WorkoutPlan
alias AfyaFit.Nutrition.NutritionPlan

IO.puts "Starting Schema Verification..."

# 1. Create Organization
{:ok, org} = AfyaFit.Organizations.create_organization(%{
  name: "Test Gym",
  subdomain: "test-gym-#{System.unique_integer()}",
  plan_type: "pro",
  status: "active"
})
IO.puts "✅ Organization created: #{org.name}"

# 2. Create Trainer
{:ok, trainer} = AfyaFit.Accounts.create_user(%{
  email: "trainer#{System.unique_integer()}@example.com",
  role: "trainer",
  first_name: "John",
  last_name: "Doe",
  password_hash: "dummy_hash",
  organization_id: org.id
})
IO.puts "✅ Trainer created: #{trainer.email}"

# 3. Create Client
{:ok, client} = AfyaFit.Accounts.create_user(%{
  email: "client#{System.unique_integer()}@example.com",
  role: "client",
  first_name: "Jane",
  last_name: "Smith",
  password_hash: "dummy_hash",
  organization_id: org.id
})
IO.puts "✅ Client created: #{client.email}"

# 4. Create Workout Plan
{:ok, plan} = AfyaFit.Workouts.create_workout_plan(%{
  organization_id: org.id,
  trainer_id: trainer.id,
  name: "Beginner Strength",
  description: "Intro to lifting",
  duration_weeks: 4,
  difficulty: "beginner"
})
IO.puts "✅ Workout Plan created: #{plan.name}"

# 5. Create Nutrition Plan
{:ok, nut_plan} = AfyaFit.Nutrition.create_nutrition_plan(%{
  organization_id: org.id,
  trainer_id: trainer.id,
  client_id: client.id,
  name: "Weight Loss",
  start_date: Date.utc_today()
})
IO.puts "✅ Nutrition Plan created: #{nut_plan.name}"

# 6. Verify Relationships
plan = AfyaFit.Workouts.get_workout_plan!(plan.id) |> AfyaFit.Repo.preload([:organization, :trainer])
if plan.organization.id == org.id and plan.trainer.id == trainer.id do
  IO.puts "✅ Workout Plan relationships verified"
else
  IO.puts "❌ Workout Plan relationships FAILED"
end
