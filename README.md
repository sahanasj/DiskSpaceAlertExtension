# Summary
An AppDynamics Machine Agent extension to alert if disk space crosses a warning or critical threshold. If a threshold is crossed, the extension will create a custom event upon which you can trigger a Policy + Action to get notified.

I tested on CentOS 7 and Ubuntu 12,14. No support for Windows yet, but that's coming.

# Configuration
`check_disk.cfg` contains the settings for the Warning and Critical thresholds as well as the Controller connection information.

Set DEBUG=true to enable echo statements that are useful for debugging the script and config. These statements are not printed to the agent log file so you'll have to run teh script directly if you're debugging.

Set MINUTE_FREQUENCY to change how often the script will run.

The other settings should be self-explanatory.

## Policies and Actions
Refer to the screenshots and PowerPoint file in the Docs/ directory.

The script will create a Custom Event if a threshold is crossed. You can create a Policy to trigger based on the Custom Event's `level` property. You can also use the Config Exporter tool to import the included policies.json file.
https://docs.appdynamics.com/display/PRO41/Configure+Policies#ConfigurePolicies-ConfigurePolicyTriggers

You'll want to test and validate that the extension is working so make sure to go to the Events page and specify the `DiskSpace` event type in the search criteria.

# Usage

## Deploy as An Extension
Copy the runtime files to the `<MACHINE_AGENT_HOME>/monitors/` directory. Your final deployment should look something like `<MACHINE_AGENT_HOME>/monitors/DiskSpaceAlertExtension/`

## Run Manually
`./check_disk.sh`

# Resources
https://docs.appdynamics.com/display/PRO41/Extensions+and+Custom+Metrics

https://docs.appdynamics.com/display/PRO41/Build+a+Monitoring+Extension+Using+Scripts
