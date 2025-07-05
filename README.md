# Tokenized Autonomous Vehicle Fleet Management Network

A comprehensive blockchain-based system for managing autonomous vehicle fleets using Clarity smart contracts on the Stacks blockchain.

## Overview

This project implements a decentralized autonomous vehicle fleet management system with five core smart contracts:

1. **Vehicle Registration Contract** - Manages autonomous vehicle identities and ownership
2. **Route Optimization Contract** - Calculates and stores efficient travel paths
3. **Maintenance Scheduling Contract** - Predicts and schedules vehicle servicing
4. **Accident Liability Contract** - Determines fault and manages compensation
5. **Revenue Sharing Contract** - Distributes earnings among fleet stakeholders

## Features

### Vehicle Registration
- Register new autonomous vehicles with unique identifiers
- Track vehicle ownership and transfer capabilities
- Store vehicle specifications and capabilities
- Manage vehicle status (active, inactive, maintenance)

### Route Optimization
- Calculate optimal routes based on distance and traffic
- Store route data for future reference
- Track route efficiency metrics
- Manage route pricing

### Maintenance Scheduling
- Predict maintenance needs based on mileage and time
- Schedule maintenance appointments
- Track maintenance history
- Calculate maintenance costs

### Accident Liability
- Record accident incidents with detailed information
- Determine fault percentages
- Calculate compensation amounts
- Manage insurance claims

### Revenue Sharing
- Distribute earnings among stakeholders
- Track revenue by vehicle and time period
- Manage stakeholder percentages
- Handle automatic payouts

## Contract Architecture

Each contract is designed to be independent and self-contained, avoiding cross-contract calls for maximum security and simplicity.

## Getting Started

### Prerequisites
- Clarinet CLI
- Node.js and npm
- Vitest for testing

### Installation

\`\`\`bash
git clone <repository-url>
cd autonomous-vehicle-fleet
npm install
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy
\`\`\`

## Contract Details

### Data Structures

Each contract maintains its own data structures optimized for its specific use case:

- **Vehicles**: Comprehensive vehicle information including specs and status
- **Routes**: Route data with optimization metrics
- **Maintenance**: Scheduling and history tracking
- **Accidents**: Incident records and liability calculations
- **Revenue**: Earnings distribution and stakeholder management

### Security Features

- Input validation on all public functions
- Access control for sensitive operations
- Error handling with descriptive error codes
- Safe arithmetic operations

## Testing

The project includes comprehensive tests using Vitest:

- Unit tests for each contract function
- Integration tests for complex workflows
- Edge case testing
- Performance testing

## Contributing

Please read the PR details file for contribution guidelines.

## License

MIT License - see LICENSE file for details.
