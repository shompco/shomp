# Shomp MVP Core 14 - Shipping Cost Calculator & Manual Label Generation

## Overview
Add real-time shipping cost calculation to checkout and manual shipping label generation for sellers.

## Core Features

### 1. Shipping Cost Calculator
- Real-time rate calculation during checkout
- Customer selects shipping method (USPS Ground, FedEx 2-Day, etc.)
- Address validation and error handling
- Fallback rates if Shippo API fails

### 2. Manual Shipping Label Generation
- "Generate Shipping Label" button for sellers
- Send tracking details to customer automatically
- Order status: pending → ready_to_ship → shipped → delivered

### 3. Shippo Integration
- Real API integration (replace mock data)
- Webhook handling for package status updates
- Support USPS, FedEx, UPS carriers

## Implementation Tasks

1. **Checkout Calculator**
   - Add shipping address form to checkout
   - Live rate calculation with Shippo API
   - Display shipping options with costs/delivery times
   - Update total price dynamically

2. **Seller Shipping UI**
   - "Generate Shipping Label" button on order management
   - Seller shipping address management
   - Order status workflow updates

3. **Shippo Integration**
   - Replace mock shipping functions with real API
   - Add webhook endpoint for package tracking
   - Handle delivery status updates automatically

4. **Database Updates**
   - Add shipping_cost to universal_orders
   - Add seller shipping addresses to stores
   - Add tracking status fields

## Dependencies
- Shippo API integration
- Address management system
- Order status workflow
