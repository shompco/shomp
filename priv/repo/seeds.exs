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
alias Shomp.Accounts.User
alias Shomp.FeatureRequests

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
  IO.puts("Feature requests already exist, skipping creation")
end
