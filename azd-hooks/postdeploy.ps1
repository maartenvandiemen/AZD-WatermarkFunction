#!/usr/bin/env pwsh

# Flex Consumption only supports Event Grid-sourced blob triggers, so the event subscription
# that routes "input/" blob uploads to the function can't be created at provision time: it
# needs the function's blob extension key, which only exists once the function code is deployed.
# This hook wires that subscription up right after `azd deploy` finishes.

# On PowerShell 7.3+ this defaults to $true, which turns a non-zero exit code from a native
# command (az) into a terminating error — that would abort the retry loop below after the very
# first failed attempt instead of actually retrying.
$PSNativeCommandUseErrorActionPreference = $false

if (!(Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Error: the Azure CLI (az) is required to configure the Event Grid subscription. See prereqs.md."
}

# Immediately after deploy, the freshly-deployed app can take a while to fully come up: the blob
# extension's system key may not be registered yet, and even once it is, Event Grid's validation
# handshake against it can still fail with a transient 401 while the key propagates to every Flex
# Consumption instance. Both `az` calls below hit this same propagation lag, so they share one
# retry helper instead of duplicating the loop.
function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)] [scriptblock]$Action,
        [Parameter(Mandatory)] [string]$Description,
        [int]$MaxAttempts = 10,
        [int]$DelaySeconds = 30
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (& $Action) {
            return
        }

        if ($attempt -lt $MaxAttempts) {
            Write-Output "$Description failed (attempt $attempt/$MaxAttempts), likely still propagating. Retrying in $DelaySeconds seconds..."
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw "Error: $Description failed after $MaxAttempts attempts."
}

Invoke-WithRetry -Description "Reading the blobs_extension key from function app '$env:AZURE_FUNCTION_APP_NAME'" -Action {
    $script:blobsExtensionKey = az functionapp keys list `
        --name $env:AZURE_FUNCTION_APP_NAME `
        --resource-group $env:AZURE_RESOURCE_GROUP `
        --query "systemKeys.blobs_extension" `
        --output tsv
    -not [string]::IsNullOrWhiteSpace($script:blobsExtensionKey)
}

# The key is base64-like and can contain characters (+, /, =) that are only safe in a query
# string once percent-encoded.
$encodedBlobsExtensionKey = [System.Uri]::EscapeDataString($blobsExtensionKey)
$webhookEndpointUrl = "https://$($env:AZURE_FUNCTION_APP_NAME).azurewebsites.net/runtime/webhooks/blobs?functionName=Host.Functions.AddWatermarkToImage&code=$encodedBlobsExtensionKey"

# `az` on Windows is az.cmd, launched through cmd.exe. An unquoted "&" in an argument gets
# treated by cmd.exe's own parser as a command separator, silently truncating the URL before
# "code=" ever reaches Event Grid. Wrapping the value in literal quote characters makes cmd.exe
# treat it as one protected token instead of splitting on the "&".
$quotedWebhookEndpointUrl = '"' + $webhookEndpointUrl + '"'

Invoke-WithRetry -Description "Creating the Event Grid subscription" -Action {
    az eventgrid system-topic event-subscription create `
        --name input-container-blob-created `
        --resource-group $env:AZURE_RESOURCE_GROUP `
        --system-topic-name $env:AZURE_STORAGE_EVENT_GRID_TOPIC_NAME `
        --endpoint-type webhook `
        --endpoint $quotedWebhookEndpointUrl `
        --included-event-types Microsoft.Storage.BlobCreated `
        --subject-begins-with /blobServices/default/containers/input `
        --output none
    $LASTEXITCODE -eq 0
}

Write-Output "Configured the Event Grid subscription that routes input/ blob uploads to AddWatermarkToImage."
