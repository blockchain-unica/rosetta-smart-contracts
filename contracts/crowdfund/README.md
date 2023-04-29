# Crowdfund

## Specification

The Crowdfund contract allows users to donate native cryptocurrency to
fund a campaign.
To create the contract, one must specify:
- the *recipient* of the funds,
- the *goal* of the campaign, that is the least amount of currency that
must be donated in order for the campaign to be succesfull,
- the *deadline* for the donations.

After creation, the following actions are possible:
- **donate**: anyone can transfer native cryptocurrency to the contract
until the deadline;
- **withdraw**: after the deadline, the recipient can withdraw the funds
stored in the contract, provided that the goal has been reached;
- **reclaim**: after the deadline, if the goal has not been reached
donors can withdraw the amounts they have donated.
