# Brevo SMTP Setup Guide

This guide explains how to configure your Shomp application to use Brevo (formerly Sendinblue) for email delivery instead of the local mail adapter.

## Changes Made

The following configuration changes have been made to switch from the local mail adapter to Brevo SMTP:

### 1. Updated `config/config.exs`
- Changed mailer adapter from `Swoosh.Adapters.Local` to `Swoosh.Adapters.SMTP`
- Added Brevo SMTP configuration with environment variables

### 2. Updated `config/dev.exs`
- Enabled Swoosh API client for SMTP adapter
- Disabled local mailbox since we're using Brevo SMTP

### 3. Updated `config/runtime.exs`
- Added production Brevo SMTP configuration
- Configured environment variable loading for production

## Required Environment Variables

You need to set the following environment variables with your Brevo SMTP credentials:

```bash
export BREVO_SMTP_USERNAME="your-brevo-smtp-username"
export BREVO_SMTP_PASSWORD="your-brevo-smtp-password"
```

## Getting Brevo SMTP Credentials

1. **Log in to your Brevo account**
2. **Navigate to SMTP & API settings**:
   - Click on your profile menu (top-right)
   - Select "SMTP & API"
3. **Get SMTP credentials**:
   - Go to the "SMTP" tab
   - Copy your SMTP username and password
   - **Important**: Use SMTP credentials, not API credentials
4. **Verify sender email**:
   - Ensure the sender email address (noreply@shomp.co) is authorized in your Brevo account

## SMTP Configuration Details

- **SMTP Server**: `smtp-relay.brevo.com`
- **Port**: 587 (with TLS)
- **Authentication**: Required
- **Encryption**: TLS (if available)
- **Retries**: 2 attempts

## Testing the Configuration

### Option 1: Use the test script
```bash
elixir test_brevo_config.exs
```

### Option 2: Test in IEx
```elixir
# Start your application
iex -S mix

# Send a test email
email = %Swoosh.Email{
  to: "test@example.com",
  from: "noreply@shomp.co",
  subject: "Test Email from Shomp",
  text_body: "This is a test email to verify Brevo SMTP configuration."
}

Shomp.Mailer.deliver(email)
```

### Option 3: Test through your application
Use any email-sending feature in your application (user registration, password reset, etc.) to verify emails are being sent through Brevo.

## Development vs Production

- **Development**: Uses Brevo SMTP with the same configuration as production
- **Testing**: Continues to use `Swoosh.Adapters.Test` for isolated testing
- **Production**: Uses Brevo SMTP with environment variables loaded at runtime

## Troubleshooting

### Common Issues

1. **"Authentication failed"**
   - Verify your SMTP username and password are correct
   - Ensure you're using SMTP credentials, not API credentials
   - Check that your Brevo account is active

2. **"Connection refused"**
   - Verify the SMTP server address: `smtp-relay.brevo.com`
   - Check that port 587 is not blocked by firewall
   - Ensure TLS is properly configured

3. **"Sender not authorized"**
   - Verify that `noreply@shomp.co` is authorized in your Brevo account
   - Check your Brevo sender verification settings

### Environment Variable Issues

If environment variables are not being loaded:

1. **Development**: Add to your shell profile (`.bashrc`, `.zshrc`, etc.)
2. **Production**: Set in your deployment environment (Heroku, Docker, etc.)
3. **Local testing**: Use a `.env` file with `dotenv` or similar

## Migration Notes

- The existing `BrevoService` module remains available for API-based email sending if needed
- All existing email functionality will now use Brevo SMTP instead of local storage
- The `/dev/mailbox` endpoint will no longer show emails (they're sent via Brevo)

## Security Considerations

- Never commit SMTP credentials to version control
- Use environment variables for all sensitive configuration
- Consider using different Brevo accounts for development and production
- Monitor your Brevo account for usage and limits

## Next Steps

1. Set up your Brevo SMTP credentials
2. Test the configuration using one of the methods above
3. Deploy to production with the environment variables set
4. Monitor email delivery through your Brevo dashboard
5. Remove the test script (`test_brevo_config.exs`) once everything is working
