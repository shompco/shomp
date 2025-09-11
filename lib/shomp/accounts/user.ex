defmodule Shomp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :name, :string
    field :bio, :string
    field :location, :string
    field :website, :string
    field :verified, :boolean, default: false
    field :role, :string, default: "user"
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :trial_ends_at, :utc_datetime

    belongs_to :tier, Shomp.Accounts.Tier, type: :binary_id
    has_many :stores, Shomp.Stores.Store
    has_many :payments, Shomp.Payments.Payment
    has_many :downloads, Shomp.Downloads.Download
    has_many :carts, Shomp.Carts.Cart
    has_many :requests, Shomp.FeatureRequests.Request

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registration.

  It requires email and name to be present. Password is optional for magic link users.
  Users can set passwords later and use both authentication methods.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name, :username])
    |> validate_email(opts)
    |> validate_username(opts)
    |> validate_required([:name, :username])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:username, min: 3, max: 30)
    |> maybe_validate_password(opts)
  end

  @doc """
  A user changeset for password-based registration.

  It requires email, password, and name to be present.
  """
  def password_registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name, :username])
    |> validate_email(opts)
    |> validate_username(opts)
    |> validate_password(opts)
    |> validate_required([:name, :username])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:username, min: 3, max: 30)
  end

  @doc """
  A user changeset for adding/updating a password.

  Can be used to add a password to a magic link user or update existing password.
  """
  def add_password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_password(opts)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  @doc """
  A user changeset for changing the username.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the username, useful when displaying live validations.
      Defaults to `true`.
  """
  def username_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username])
    |> validate_username(opts)
  end

  @doc """
  A user changeset for updating profile information.
  """
  def profile_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:username, :name, :bio, :location, :website])
    |> validate_required([:username])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_length(:name, min: 2, max: 100)
    |> validate_length(:bio, max: 500)
    |> validate_length(:location, max: 100)
    |> validate_length(:website, max: 200)
    |> validate_format(:website, ~r/^https?:\/\/.+/, message: "must be a valid URL starting with http:// or https://")
    |> validate_username(opts)
    |> maybe_validate_website()
  end

  defp maybe_validate_website(changeset) do
    website = get_change(changeset, :website)

    if website && website != "" do
      validate_format(changeset, :website, ~r/^https?:\/\/.+/, message: "must be a valid URL starting with http:// or https://")
    else
      changeset
    end
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, Shomp.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  defp validate_username(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:username])
      |> validate_format(:username, ~r/^[a-zA-Z0-9_-]+$/,
        message: "can only contain letters, numbers, underscores, and hyphens"
      )
      |> validate_length(:username, min: 3, max: 30)
      |> validate_username_blacklist()
      |> validate_username_store_conflict()

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:username, Shomp.Repo)
      |> unique_constraint(:username)
    else
      changeset
    end
  end

  defp validate_username_blacklist(changeset) do
    username = get_change(changeset, :username) || get_field(changeset, :username)

    if username do
      # Check if username is in reserved words list (case insensitive)
      if String.downcase(username) in reserved_usernames() do
        add_error(changeset, :username, "that name is taken")
      else
        changeset
      end
    else
      changeset
    end
  end

  # Reserved usernames that should not be allowed
  defp reserved_usernames do
    # Application routes and core functionality
    application_reserved = [
      "dashboard", "admin", "api", "payments", "checkout", "stores", "users",
      "orders", "support", "notifications", "cart", "downloads", "reviews",
      "categories", "requests", "about", "mission", "donations", "landing",
      "settings", "profile", "register", "login", "logout", "password", "email",
      "tier", "upgrade", "addresses", "purchases", "refunds", "webhook"
    ]

    # Common system/technical terms
    system_reserved = [
      "www", "mail", "ftp", "smtp", "pop", "imap", "dns", "ssl", "tls", "http",
      "https", "ftp", "ssh", "root", "system", "service", "server", "client",
      "app", "api", "dev", "test", "staging", "production", "local", "host",
      "null", "undefined", "true", "false", "none", "nil", "void"
    ]

    # Common social media and platform terms
    platform_reserved = [
      "facebook", "twitter", "instagram", "linkedin", "youtube", "tiktok",
      "snapchat", "pinterest", "reddit", "discord", "telegram", "whatsapp",
      "github", "gitlab", "bitbucket", "stackoverflow", "medium", "dev"
    ]

    # Combine all reserved word lists
    application_reserved ++ system_reserved ++ platform_reserved
  end

  defp validate_username_store_conflict(changeset) do
    username = get_change(changeset, :username) || get_field(changeset, :username)

    if username do
      # Convert username to store slug format for comparison
      potential_store_slug = username
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

      # Check if this would conflict with an existing store slug
      case Shomp.Repo.get_by(Shomp.Stores.Store, slug: potential_store_slug) do
        nil -> changeset
        _store ->
          add_error(changeset, :username, "username conflicts with existing store name '#{potential_store_slug}'. Please choose a different username.")
      end
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.


  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      # If using Bcrypt, then further validate it is at most 72 bytes long
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_password(changeset, opts) do
    password = get_change(changeset, :password)

    if password do
      validate_password(changeset, opts)
    else
      changeset
    end
  end
end
        "tutorials",
        "faq",
        "faqs",
        "ticket",
        "tickets",
        "issue",
        "issues",
        "bug",
        "bugs",
        "feature",
        "features",
        "request",
        "requests",
        "feedback",
        "suggestions",
        "report",
        "reports",
        "abuse",
        "spam",
        "moderation",
        "moderator",
        "moderators",
        "staff",
        "team",
        "teams",
        "company",
        "companies",
        "business",
        "businesses",
        "organization",
        "organizations",
        "institution",
        "institutions",
        "government",
        "official",
        "public",
        "private",
        "internal",
        "external",
        "system",
        "systems",
        "service",
        "services",
        "app",
        "apps",
        "application",
        "applications",
        "platform",
        "platforms",
        "software",
        "hardware",
        "device",
        "devices",
        "mobile",
        "desktop",
        "web",
        "internet",
        "network",
        "networks",
        "server",
        "servers",
        "hosting",
        "cloud",
        "aws",
        "azure",
        "google",
        "microsoft",
        "apple",
        "facebook",
        "twitter",
        "instagram",
        "youtube",
        "tiktok",
        "linkedin",
        "github",
        "gitlab",
        "bitbucket",
        "stackoverflow",
        "reddit",
        "discord",
        "slack",
        "telegram",
        "whatsapp",
        "snapchat",
        "pinterest",
        "tumblr",
        "medium",
        "substack",
        "patreon",
        "kickstarter",
        "indiegogo",
        "gofundme",
        "paypal",
        "stripe",
        "square",
        "venmo",
        "cashapp",
        "zelle",
        "bitcoin",
        "crypto",
        "cryptocurrency",
        "blockchain",
        "nft",
        "nfts",
        "metaverse",
        "vr",
        "ar",
        "ai",
        "ml",
        "machinelearning",
        "datascience",
        "analytics",
        "metrics",
        "stats",
        "statistics",
        "reports",
        "dashboards",
        "charts",
        "graphs",
        "visualization",
        "data",
        "database",
        "databases",
        "sql",
        "nosql",
        "mongodb",
        "postgresql",
        "mysql",
        "redis",
        "elasticsearch",
        "kibana",
        "grafana",
        "prometheus",
        "influxdb",
        "timescale",
        "cassandra",
        "dynamodb",
        "s3",
        "ec2",
        "lambda",
        "cloudfront",
        "route53",
        "rds",
        "elasticache",
        "sqs",
        "sns",
        "ses",
        "iam",
        "vpc",
        "subnet",
        "security",
        "securitygroup",
        "firewall",
        "ssl",
        "tls",
        "https",
        "http",
        "ftp",
        "sftp",
        "ssh",
        "telnet",
        "dns",
        "ip",
        "ipv4",
        "ipv6",
        "tcp",
        "udp",
        "icmp",
        "arp",
        "routing",
        "switching",
        "loadbalancer",
        "loadbalancing",
        "cdn",
        "cache",
        "caching",
        "compression",
        "gzip",
        "brotli",
        "minification",
        "bundling",
        "webpack",
        "rollup",
        "vite",
        "parcel",
        "babel",
        "typescript",
        "javascript",
        "nodejs",
        "npm",
        "yarn",
        "pnpm",
        "bun",
        "deno",
        "react",
        "vue",
        "angular",
        "svelte",
        "ember",
        "backbone",
        "jquery",
        "bootstrap",
        "tailwind",
        "bulma",
        "foundation",
        "materialize",
        "semantic",
        "antd",
        "chakra",
        "mantine",
        "nextjs",
        "nuxt",
        "gatsby",
        "sveltekit",
        "remix",
        "astro",
        "solid",
        "qwik",
        "lit",
        "stencil",
        "polymer",
        "elm",
        "clojure",
        "clojurescript",
        "reason",
        "reasonml",
        "ocaml",
        "fsharp",
        "haskell",
        "erlang",
        "elixir",
        "phoenix",
        "liveview",
        "ecto",
        "absinthe",
        "graphql",
        "apollo",
        "relay",
        "urql",
        "graphqljs",
        "prisma",
        "hasura",
        "fauna",
        "supabase",
        "firebase",
        "vercel",
        "netlify",
        "heroku",
        "railway",
        "render",
        "fly",
        "digitalocean",
        "linode",
        "vultr",
        "gcp",
        "ibm",
        "oracle",
        "alibaba",
        "tencent",
        "baidu",
        "yandex",
        "naver",
        "kakao",
        "line",
        "wechat",
        "weibo",
        "qq",
        "taobao",
        "tmall",
        "jd",
        "pinduoduo",
        "meituan",
        "didi",
        "grab",
        "gojek",
        "uber",
        "lyft",
        "airbnb",
        "booking",
        "expedia",
        "priceline",
        "kayak",
        "skyscanner",
        "trivago",
        "hotels",
        "agoda",
        "tripadvisor",
        "yelp",
        "foursquare",
        "swarm",
        "untappd",
        "goodreads",
        "letterboxd",
        "lastfm",
        "spotify",
        "apple_music",
        "tidal",
        "pandora",
        "soundcloud",
        "bandcamp",
        "mixcloud",
        "audible",
        "overdrive",
        "libby",
        "hoopla",
        "kanopy",
        "criterion",
        "mubi",
        "hulu",
        "disney",
        "netflix",
        "amazon_prime",
        "hbo_max",
        "paramount",
        "peacock",
        "apple_tv",
        "youtube_tv",
        "sling",
        "fubo",
        "directv",
        "dish",
        "comcast",
        "verizon",
        "att",
        "t_mobile",
        "sprint",
        "boost",
        "cricket",
        "metropcs",
        "straight_talk",
        "total_wireless",
        "visible",
        "mint",
        "google_fi",
        "project_fi",
        "republic_wireless",
        "ting",
        "consumer_cellular",
        "us_cellular",
        "c_spire",
        "pioneer",
        "unreal",
        "unity",
        "godot",
        "blender",
        "maya",
        "3ds_max",
        "cinema_4d",
        "houdini",
        "nuke",
        "after_effects",
        "premiere",
        "final_cut",
        "davinci",
        "resolve",
        "avid",
        "pro_tools",
        "logic",
        "cubase",
        "ableton",
        "fl_studio",
        "reason",
        "bitwig",
        "studio_one",
        "reaper",
        "garageband",
        "audacity",
        "lmms",
        "ardour",
        "mixcraft",
        "cakewalk",
        "sonar",
        "acid",
        "soundforge",
        "wavelab",
        "izotope",
        "waves",
        "fabfilter",
        "native_instruments",
        "arturia",
        "u_he",
        "xfer",
        "serum",
        "massive",
        "kontakt",
        "battery",
        "maschine",
        "komplete",
        "guitar_rig",
        "reaktor",
        "absynth",
        "fm8",
        "monark",
        "prism",
        "rounds",
        "pharlight"
      ]

      # Check if username is in blacklist (case insensitive)
      if String.downcase(username) in blacklisted_usernames do
        add_error(changeset, :username, "that name is taken")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp validate_username_store_conflict(changeset) do
    username = get_change(changeset, :username) || get_field(changeset, :username)

    if username do
      # Convert username to store slug format for comparison
      potential_store_slug = username
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9-]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

      # Check if this would conflict with an existing store slug
      case Shomp.Repo.get_by(Shomp.Stores.Store, slug: potential_store_slug) do
        nil -> changeset
        _store ->
          add_error(changeset, :username, "username conflicts with existing store name '#{potential_store_slug}'. Please choose a different username.")
      end
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.


  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 12, max: 72)
    # Examples of additional password validation:
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  defp maybe_validate_password(changeset, opts) do
    password = get_change(changeset, :password)

    if password do
      validate_password(changeset, opts)
    else
      changeset
    end
  end

  @doc """
  A user changeset for updating tier information.
  """
  def tier_changeset(user, attrs) do
    user
    |> cast(attrs, [:tier_id, :trial_ends_at])
    |> validate_required([:tier_id])
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Shomp.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end
end
