# Deployments

This directory stores public deployment artifacts for Vigilia Protocol.

Deployment JSON files are safe to commit. They contain deployed contract addresses, public network metadata, and non-secret deployment configuration so reviewers and demo operators can reproduce which contracts were deployed and how they were configured.

The `.env` file contains private or local inputs, including private keys and machine-specific settings, and must not be committed. Deployment JSON may intentionally duplicate non-secret `.env` values because it is the public output snapshot of a deployment.

Foundry broadcast traces remain under `broadcast/`. Those traces are useful for debugging, but they are not the canonical public deployment artifact for this project.

Local scratch artifacts can use `*.local.json`; those files are ignored by git.
