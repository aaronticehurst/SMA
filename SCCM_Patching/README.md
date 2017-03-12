# SMA
SMA SCCM patching for complex patching.

CSV for input should be in format of ComputerName, SnapShotDescription, Reason, Comment, Hours

This is a sanitised version of workflows I wrote for controlled patching with SCCM at work. It can be used against server 2003 to 2016 which has the SCCM agent installed.

It should be tested in dev before using in production.

It will patch one or many servers at once and dependent on workflow will do any additional work before and after patching like in Invoke-PatchSCSMEnvironment unpublish SCSM service requests so no new requests can be submitted during patching and then republish them afterwards.

3 example patching scenarios are provided, Invoke-PatchParallelServer, Invoke-PatchSequentialServer, Invoke-PatchSCSMEnvironment. Additoanl workflow front end scripts can be written for other scenarios which then call the main body workflow of Invoke-PatchWorkflow to do the actual workflow, example would be pulling a server out of a load balancer.
