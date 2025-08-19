# Shomp 🛒

**Sell stuff online and keep 100%**

Shomp is an open-source e-commerce platform built on Elixir (Erlang) that empowers creators and artists to make a gainful livelihood through selling their creations.
We aspire to be a 501c3 nonprofit to help US-based artists keep 100% of their proceeds when selling on Shomp.

## 🎯 Our Mission

Our mission is to empower creators and artists to make gainful livelihood through selling their creations. Shomp provides a platform where creators can focus on what they do best - creating - while we handle the commerce infrastructure.

## ✨ Key Features

### 🔓 **Open Source & Transparent**
- Built on Elixir (Erlang) for reliability and performance
- Complete transparency in development and operations
- Community-driven development and feature requests
- No vendor lock-in - you can always self-host

### 💰 **Zero Platform Fees**
- **Creators keep 100% of their earnings** from sales
- No hidden fees, no percentage cuts, no surprise charges
- Only standard payment processing fees apply (Stripe's ~2.9%)
- We believe creators should be rewarded for their work, not the platform

### 🎨 **Creator-Focused Features**
- **Digital Product Sales** - PDFs, music, art, courses, software
- **Physical Product Sales** - art prints, crafts, merchandise
- **Service Listings** - consultations, custom work, commissions
- **Secure Download System** - automatic delivery for digital products
- **Custom Store Pages** - personalized storefronts with custom URLs
- **Integrated Payment Processing** - powered by Stripe for security

### 🛡️ **Secure & Reliable**
- Secure file delivery with access controls
- User authentication with email/password and magic links
- Payment security handled by Stripe
- Download tracking and limits
- GDPR-compliant data handling

## 💝 Funding Model

Shomp is **sustained completely by donations** from the community who believe in our mission. Our goals are:

- **Never charging platform fees** to creators
- **Keeping the platform completely free** for sellers
- **Maintaining full transparency** in our operations
- **Being open-minded to ethical revenue streams** like advertising to help cover operational costs, if needed in the future

Every contribution helps us continue building tools that empower creators worldwide.

### Why Donations?

We believe that taking a percentage of creator earnings creates misaligned incentives. Instead of optimizing for maximum transaction volume (which benefits us), we can focus purely on what's best for creators - building better tools, improving the user experience, and keeping costs low.

## 🚀 Quick Start

### Prerequisites
- Elixir 1.18+ 
- Erlang/OTP 26+
- PostgreSQL 14+
- Node.js 18+ (for asset compilation)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/shompco/shomp.git
   cd shomp
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```

3. **Set up the database**
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

4. **Configure Stripe** (for payments)
   ```bash
   export STRIPE_SECRET_KEY=sk_test_...
   export STRIPE_PUBLISHABLE_KEY=pk_test_...
   ```

5. **Start the server**
   ```bash
   mix phx.server
   ```

6. **Visit your app**
   Open [http://localhost:4000](http://localhost:4000) in your browser

### Environment Variables

For development, you can create a `.env` file (not committed to git):

```bash
# Stripe Test Keys (get these from https://dashboard.stripe.com/test/apikeys)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...

# Stripe Webhook Secret (for local testing)
STRIPE_WEBHOOK_SECRET=whsec_...

# Database URL (optional, defaults to local postgres)
DATABASE_URL=postgresql://username:password@localhost/shomp_dev
```

## 📖 Documentation

- **[Stripe Setup Guide](STRIPE_SETUP.md)** - Complete guide for payment processing setup
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute to the project
- **[Deployment Guide](DEPLOYMENT.md)** - Production deployment instructions
- **[API Documentation](API.md)** - REST API and webhook documentation

## 🛠️ Tech Stack

- **Backend**: Elixir, Phoenix Framework, Phoenix LiveView
- **Database**: PostgreSQL with Ecto ORM
- **Payments**: Stripe for secure payment processing
- **Frontend**: Phoenix LiveView with Tailwind CSS + DaisyUI
- **File Storage**: Local storage (S3 support planned)
- **Authentication**: Phoenix Auth with email/password and magic links

## 🌟 Roadmap

### Currently Available (MVP)
- ✅ User authentication and registration
- ✅ Store creation and management
- ✅ Product listings (digital, physical, services)
- ✅ Stripe payment integration
- ✅ Secure download system for digital products
- ✅ Donation system for platform support

### Coming Soon
- 📧 Address management for physical products
- 🎨 Enhanced store customization
- 📊 Analytics and reporting
- 🔗 Webhook integrations
- 📱 Mobile app
- 🌍 International payment support
- 🎯 Feature request system with community voting

## 🤝 Contributing

We welcome contributions from the community! Here's how you can help:

1. **Report bugs** or suggest features via [GitHub Issues](https://github.com/shompco/shomp/issues)
2. **Submit pull requests** for bug fixes or new features
3. **Improve documentation** - even small fixes help
4. **Spread the word** - tell other creators about Shomp
5. **Make a donation** - help us keep the platform running

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Run the test suite: `mix test`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to your branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 💖 Support the Project

If Shomp has helped you sell your creations, consider supporting the project:

- **[Donate via the platform](http://localhost:4000/about)** - Direct donations through Shomp
- **⭐ Star this repository** - Help others discover the project
- **🐦 Share on social media** - Spread the word to other creators
- **📝 Write a blog post** - Share your success story

## 📜 License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## 📞 Support & Community

- **🐛 Bug Reports**: [GitHub Issues](https://github.com/shompco/shomp/issues)
- **💡 Feature Requests**: [GitHub Discussions](https://github.com/shompco/shomp/discussions)
- **📧 Email**: support@shomp.co

---

**Built with ❤️ for creators, by creators.**

*Shomp is committed to empowering the creative economy while maintaining complete transparency and ethical business practices. We believe the best platforms are built by and for their communities.*