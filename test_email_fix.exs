#!/usr/bin/env elixir

# Test script to verify Brevo SMTP configuration
# Run with: elixir test_email_fix.exs

# Load the application
Mix.install([
  {:swoosh, "~> 1.0"},
  {:req, "~> 0.4"}
])

# Set up basic configuration
Application.put_env(:shomp, Shomp.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: "smtp-relay.brevo.com",
  port: 587,
  username: System.get_env("BREVO_SMTP_USERNAME"),
  password: System.get_env("BREVO_SMTP_PASSWORD"),
  ssl: false,
  tls: :if_available,
  auth: :always,
  retries: 2
)

# Configure Swoosh
Application.put_env(:swoosh, :api_client, Swoosh.ApiClient.Req)

# Start Swoosh
Application.ensure_all_started(:swoosh)

# Create a test email
email = %Swoosh.Email{
  to: "v1nc3ntpull1ng@gmail.com",
  from: "noreply@shomp.co",
  subject: "Test Email - Brevo SMTP Configuration Fix",
  text_body: """
  This is a test email to verify that the Brevo SMTP configuration is working correctly.
  
  Changes made:
  1. Updated SMTP server from smtp-relay.sendinblue.com to smtp-relay.brevo.com
  2. Changed TLS setting from :always to :if_available
  
  If you receive this email, the configuration is working!
  """,
  html_body: """
  <h2>Test Email - Brevo SMTP Configuration Fix</h2>
  <p>This is a test email to verify that the Brevo SMTP configuration is working correctly.</p>
  
  <h3>Changes made:</h3>
  <ul>
    <li>Updated SMTP server from smtp-relay.sendinblue.com to smtp-relay.brevo.com</li>
    <li>Changed TLS setting from :always to :if_available</li>
  </ul>
  
  <p><strong>If you receive this email, the configuration is working!</strong></p>
  """
}

IO.puts("🔧 Testing Brevo SMTP configuration...")
IO.puts("📧 Sending test email to: #{email.to}")
IO.puts("📤 From: #{email.from}")
IO.puts("📋 Subject: #{email.subject}")

# Send the email
case Swoosh.Adapters.SMTP.deliver(email, Application.get_env(:shomp, Shomp.Mailer)) do
  {:ok, _result} ->
    IO.puts("✅ SUCCESS: Email sent successfully!")
    IO.puts("📬 Check your inbox for the test email.")
    
  {:error, reason} ->
    IO.puts("❌ ERROR: Failed to send email")
    IO.puts("🔍 Error details: #{inspect(reason)}")
    
    # Provide troubleshooting suggestions
    IO.puts("\n🔧 Troubleshooting suggestions:")
    IO.puts("1. Verify BREVO_SMTP_USERNAME and BREVO_SMTP_PASSWORD environment variables")
    IO.puts("2. Check that your Brevo account is active")
    IO.puts("3. Ensure noreply@shomp.co is authorized in your Brevo account")
    IO.puts("4. Try using port 465 with ssl: true instead of port 587 with tls")
    
  other ->
    IO.puts("❌ UNEXPECTED ERROR: #{inspect(other)}")
end

IO.puts("\n🏁 Test completed.")
