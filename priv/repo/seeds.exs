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

# Get or create admin user
admin_user = case Repo.get_by(User, email: "admin@shomp.co") do
  nil ->
    # Try to get existing user with admin username first
    case Repo.get_by(User, username: "admin") do
      nil ->
        # Create new admin user without password (they can set it later)
        %User{}
        |> User.registration_changeset(%{
          email: "admin@shomp.co",
          name: "Shomp Admin",
          username: "admin"
        }, validate_unique: false)
        |> Repo.insert!()

      existing_user ->
        # Update existing user's email if needed
        existing_user
        |> Ecto.Changeset.change(%{email: "admin@shomp.co"})
        |> Repo.update!()
    end

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

# Get or create Vincent admin user
vincent_admin = case Repo.get_by(User, email: "v1nc3ntpull1ng@gmail.com") do
  nil ->
    # Try to get existing user with vincent username first
    case Repo.get_by(User, username: "vincent") do
      nil ->
        # Create new admin user without password (they can set it later)
        %User{}
        |> User.registration_changeset(%{
          email: "v1nc3ntpull1ng@gmail.com",
          name: "Vincent",
          username: "vincent"
        }, validate_unique: false)
        |> Repo.insert!()

      existing_user ->
        # Update existing user's email if needed
        existing_user
        |> Ecto.Changeset.change(%{email: "v1nc3ntpull1ng@gmail.com"})
        |> Repo.update!()
    end

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

# Load donation seeds
Code.eval_file("priv/repo/seeds_donations.exs")
