# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :shomp, :scopes,
  user: [
    default: true,
    module: Shomp.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :id,
    schema_table: :users,
    test_data_fixture: Shomp.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :shomp,
  ecto_repos: [Shomp.Repo],
  generators: [timestamp_type: :utc_datetime],
  stripe_publishable_key: System.get_env("STRIPE_PUBLISHABLE_KEY"),
  beehiiv_api_key: System.get_env("BEEHIIV_API_KEY"),
  beehiiv_publication_id: System.get_env("BEEHIIV_PUBLICATION_ID"),
  shippo_api_key: System.get_env("SHIPPO_LIVE_KEY")

# Configures the endpoint
config :shomp, ShompWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ShompWeb.ErrorHTML, json: ShompWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Shomp.PubSub,
  live_view: [signing_salt: "rceH+mrN"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :shomp, Shomp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp-relay.brevo.com",
  port: 587,
  username: System.get_env("BREVO_SMTP_USERNAME"),
  password: System.get_env("BREVO_SMTP_PASSWORD"),
  tls: :always,
  auth: :always

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  shomp: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  shomp: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import upload configuration
import_config "upload.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
