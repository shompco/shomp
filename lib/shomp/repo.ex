defmodule Shomp.Repo do
  use Ecto.Repo,
    otp_app: :shomp,
    adapter: Ecto.Adapters.Postgres
end
