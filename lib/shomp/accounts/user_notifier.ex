defmodule Shomp.Accounts.UserNotifier do
  import Swoosh.Email

  alias Shomp.Mailer
  alias Shomp.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    require Logger
    Logger.info("Attempting to send email to: #{recipient}")

    email =
      new()
      |> to(recipient)
      |> from({"Shomp", "shomp@shomp.co"})
      |> subject(subject)
      |> text_body(body)

    case Mailer.deliver(email) do
      {:ok, _metadata} ->
        Logger.info("Email sent successfully to: #{recipient}")
        {:ok, email}
      {:error, reason} ->
        Logger.error("Failed to send email to #{recipient}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    require Logger
    Logger.info("📧 LOGIN DEBUG: UserNotifier.deliver_login_instructions called for: #{user.email}")
    Logger.info("📧 LOGIN DEBUG: User confirmed_at: #{inspect(user.confirmed_at)}")

    result = case user do
      %User{confirmed_at: nil} ->
        Logger.info("📧 LOGIN DEBUG: User not confirmed, sending confirmation instructions")
        deliver_confirmation_instructions(user, url)
      _ ->
        Logger.info("📧 LOGIN DEBUG: User confirmed, sending magic link instructions")
        deliver_magic_link_instructions(user, url)
    end

    Logger.info("📧 LOGIN DEBUG: UserNotifier.deliver_login_instructions result: #{inspect(result)}")
    result
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end
end
