# Music Royalty Distribution System

A decentralized music royalty distribution platform built on Stacks blockchain using Clarity smart contracts.

## Overview

This system automates the distribution of music royalties to creators, publishers, and rights holders based on streaming data and ownership verification. The platform consists of five interconnected smart contracts that handle different aspects of the royalty distribution process.

## System Architecture

### 1. Song Registration Contract (`song-registry.clar`)
- Records composition ownership and rights
- Manages song metadata and registration
- Tracks ownership percentages for multiple rights holders
- Handles song registration fees and validation

### 2. Streaming Tracking Contract (`streaming-tracker.clar`)
- Monitors play counts across different platforms
- Records streaming events with timestamps
- Aggregates streaming data for royalty calculations
- Prevents duplicate streaming entries

### 3. Revenue Calculation Contract (`revenue-calculator.clar`)
- Determines royalty payments based on streaming usage
- Calculates payments using configurable rates
- Handles different revenue streams (streaming, licensing, etc.)
- Manages revenue distribution formulas

### 4. Rights Holder Verification Contract (`rights-verifier.clar`)
- Validates ownership claims and percentage splits
- Manages rights holder registration and verification
- Handles ownership transfer and updates
- Maintains verified rights holder registry

### 5. Payment Distribution Contract (`payment-distributor.clar`)
- Automates royalty payments to creators
- Manages payment schedules and distributions
- Handles payment claims and withdrawals
- Tracks payment history and balances

## Key Features

- **Transparent Ownership**: All ownership data is recorded on-chain
- **Automated Payments**: Smart contracts handle royalty distributions
- **Multi-Platform Support**: Tracks streams from various platforms
- **Flexible Splits**: Supports complex ownership percentage arrangements
- **Audit Trail**: Complete transaction history for all payments
- **Dispute Resolution**: Built-in mechanisms for ownership verification

## Data Structures

### Song Registration
- Song ID (unique identifier)
- Title and artist information
- Registration timestamp
- Rights holder mappings with percentages
- Registration status and fees

### Streaming Data
- Platform identifier
- Play count and timestamps
- Geographic data (optional)
- Revenue per stream rates

### Rights Holders
- Principal addresses
- Verification status
- Ownership percentages
- Contact information hash

### Payment Records
- Payment amounts and dates
- Recipient information
- Revenue source tracking
- Claim status

## Usage Flow

1. **Registration**: Artists register songs with ownership details
2. **Verification**: Rights holders verify their ownership claims
3. **Streaming**: Platforms report streaming data to the tracker
4. **Calculation**: Revenue calculator determines payment amounts
5. **Distribution**: Payment distributor handles automated payouts

## Security Features

- Input validation on all contract functions
- Access control for administrative functions
- Protection against reentrancy attacks
- Overflow protection for mathematical operations
- Ownership verification requirements

## Testing

The system includes comprehensive tests using Vitest covering:
- Contract deployment and initialization
- Song registration workflows
- Streaming data recording
- Revenue calculation accuracy
- Payment distribution mechanics
- Error handling and edge cases

## Configuration

- Configurable streaming rates per platform
- Adjustable registration fees
- Customizable payment schedules
- Platform-specific revenue sharing rules

## Getting Started

1. Install dependencies: `npm install`
2. Run tests: `npm test`
3. Deploy contracts using Clarinet
4. Configure platform integrations
5. Begin song registration process

## Contract Addresses

After deployment, update this section with the deployed contract addresses for each component of the system.
