# Seeds for donation system
alias Shomp.Donations

# Create a default donation goal if none exists
case Donations.get_current_goal() do
  nil ->
    {:ok, _goal} = Donations.set_goal(%{
      title: "Shomp Development Fund",
      description: "Help us build new features, improve performance, and keep Shomp free for creators. Your support directly funds development time and server costs.",
      target_amount: Decimal.new("5000.00"),
      current_amount: Decimal.new("0.00"),
      status: "active"
    })

    IO.puts("✅ Created default donation goal")

  _goal ->
    IO.puts("ℹ️  Donation goal already exists")
end
