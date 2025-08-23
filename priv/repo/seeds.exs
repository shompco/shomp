# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Shomp.Repo.insert!(%Shomp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Create a test user for feature requests
alias Shomp.Repo
alias Shomp.Accounts.{User, Tier}
alias Shomp.FeatureRequests

# Create default tiers if they don't exist
tiers = [
  %{
    name: "Free",
    slug: "free",
    store_limit: 1,
    product_limit_per_store: 100,
    monthly_price: Decimal.new("0.00"),
    features: ["Basic support"],
    sort_order: 1
  },
  %{
    name: "Plus",
    slug: "plus", 
    store_limit: 3,
    product_limit_per_store: 500,
    monthly_price: Decimal.new("10.00"),
    features: ["Priority support", "Analytics", "Support Shomp"],
    sort_order: 2
  },
  %{
    name: "Pro",
    slug: "pro",
    store_limit: 10,
    product_limit_per_store: 1000,
    monthly_price: Decimal.new("20.00"),
    features: ["Priority support", "Advanced analytics", "Support Shomp"],
    sort_order: 3
  }
]

for tier_attrs <- tiers do
  %Tier{}
  |> Tier.changeset(tier_attrs)
  |> Repo.insert!(on_conflict: :nothing)
end

IO.puts("Created default tiers")

# Create a test user if it doesn't exist
test_user = case Repo.get_by(User, email: "test@example.com") do
  nil ->
    %User{}
    |> User.registration_changeset(%{
      email: "test@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      name: "Test User",
      username: "testuser"
    })
    |> Repo.insert!()
  
  user -> user
end

# Create some sample feature requests
if Repo.aggregate(Shomp.FeatureRequests.Request, :count) == 0 do
  # Request 1
  {:ok, _} = FeatureRequests.create_request(%{
    title: "Dark Mode Support",
    description: "Add a dark theme option to the application for better user experience in low-light environments.",
    status: "open",
    priority: 1
  }, test_user.id)

  # Request 2
  {:ok, _} = FeatureRequests.create_request(%{
    title: "Mobile App",
    description: "Create a native mobile application for iOS and Android platforms.",
    status: "open",
    priority: 2
  }, test_user.id)

  # Request 3
  {:ok, _} = FeatureRequests.create_request(%{
    title: "Advanced Search",
    description: "Implement advanced search filters and sorting options for better product discovery.",
    status: "in_progress",
    priority: 3
  }, test_user.id)

  IO.puts("Created sample feature requests")
else
  IO.puts("Feature requests already exist, skipping...")
end

# Create admin user if it doesn't exist
admin_user = case Repo.get_by(User, email: "admin@shomp.co") do
  nil ->
    %User{}
    |> User.registration_changeset(%{
      email: "admin@shomp.co",
      password: "admin123456789",
      password_confirmation: "admin123456789",
      name: "Shomp Admin",
      username: "admin"
    })
    |> Repo.insert!()
  
  user -> user
end

# Set admin role
if admin_user.role != "admin" do
  admin_user
  |> Ecto.Changeset.change(%{role: "admin"})
  |> Repo.update!()
  IO.puts("Updated user to admin role")
else
  IO.puts("Admin user already exists with admin role")
end

# Create additional admin user v1nc3ntpull1ng@gmail.com
vincent_admin = case Repo.get_by(User, email: "v1nc3ntpull1ng@gmail.com") do
  nil ->
    %User{}
    |> User.registration_changeset(%{
      email: "v1nc3ntpull1ng@gmail.com",
      password: "vincent123456789",
      password_confirmation: "vincent123456789",
      name: "Vincent",
      username: "vincent"
    })
    |> Repo.insert!()
  
  user -> user
end

# Set admin role for Vincent
if vincent_admin.role != "admin" do
  vincent_admin
  |> Ecto.Changeset.change(%{role: "admin"})
  |> Repo.update!()
  IO.puts("Updated Vincent to admin role")
else
  IO.puts("Vincent admin user already exists with admin role")
end
