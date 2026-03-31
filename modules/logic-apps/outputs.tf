output "function_app_syncer_name" {
  description = "Name of the function app syncer workflow"
  value       = azapi_resource.function_app_syncer.name
}

output "register_service_account_name" {
  description = "Name of the register service account workflow"
  value       = azapi_resource.register_service_account.name
}

output "workflow_names" {
  description = "Map of all Logic App workflow names"
  value = {
    functionAppSyncer        = azapi_resource.function_app_syncer.name
    registerServiceAccount   = azapi_resource.register_service_account.name
    deregisterServiceAccount = azapi_resource.deregister_service_account.name
    pollBasedDiscover        = azapi_resource.poll_based_discover.name
    discoverResources        = azapi_resource.discover_resources.name
    demandBasedDiscover      = azapi_resource.demand_based_discover.name
    findScanCandidates       = azapi_resource.find_scan_candidates.name
    createSnapshots          = azapi_resource.create_snapshots.name
    createDisks              = azapi_resource.create_disks.name
    concurrentScanner        = azapi_resource.concurrent_scanner.name
    prepareScanner           = azapi_resource.prepare_scanner.name
    runCommands              = azapi_resource.run_commands.name
    deleteSnapshots          = azapi_resource.delete_snapshots.name
    deleteDisks              = azapi_resource.delete_disks.name
    deleteNics               = azapi_resource.delete_nics.name
    deletePublicIps          = azapi_resource.delete_public_ips.name
    deleteScannerMachines    = azapi_resource.delete_scanner_machines.name
    cleanupResources         = azapi_resource.cleanup_resources.name
    uploadQscannerArtifacts  = azapi_resource.upload_qscanner_artifacts.name
  }
}
