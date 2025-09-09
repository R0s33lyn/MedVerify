# MedVerify

A decentralized medical research data validation and peer review platform built on the Stacks blockchain. MedVerify enables researchers, reviewers, and institutions to validate, cite, and rate medical research studies while earning tokens based on peer review activities and methodology assessments.

## Features

- **Entity Registration**: Researchers, reviewers, and institutions can register and manage their profiles
- **Study Submission**: Researchers can submit medical studies with cryptographic data integrity
- **Peer Review System**: Multiple reviewers can validate research methodology and findings
- **Citation Tracking**: Track and reward research citations and academic impact
- **Methodology Rating System**: Community-driven rating system for research quality
- **Token Rewards**: Entities earn tokens for peer review activities and high-quality research
- **Publication System**: Build research reputation through consistent quality and peer validation

## Smart Contract Functions

### Entity Management
- `register-entity`: Register as a researcher, reviewer, or institution
- `update-entity`: Update entity profile information

### Research Operations
- `submit-study`: Submit new medical research studies for peer review
- `peer-review-study`: Conduct peer review of research studies
- `cite-study`: Cite verified research studies in academic work
- `rate-study-methodology`: Rate the methodology and quality of research studies

### Read-Only Functions
- `get-entity-info`: Retrieve entity profile and statistics
- `get-study`: Get detailed study information and review history
- `get-total-studies`: Get total number of studies in the system

## Getting Started

1. Deploy the contract to Stacks blockchain
2. Register your entity using `register-entity`
3. Start submitting studies or conducting peer reviews
4. Participate in the methodology rating system to earn tokens and build reputation

## Token Economics

- **Review Reward**: 5 tokens per peer review conducted
- **Publication Reward**: 50 tokens when study reaches verified status
- **Excellence Reward**: 20 tokens for high-quality methodology ratings
- **Rating Participation**: 2 tokens per methodology rating submitted

## Requirements

- Stacks blockchain connection
- Clarinet for local development and testing
- Valid entity registration to participate in medical research validation
